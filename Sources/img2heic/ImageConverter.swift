import CoreGraphics
import CoreImage
import Foundation
import ImageIO

enum ConversionMode: String, Equatable {
  case preservedGainMap = "HDR with preserved gain map"
  case generatedGainMap = "HDR with generated gain map"
  case tenBitSDR = "10-bit SDR"
  case eightBitSDR = "8-bit SDR"
}

struct ConversionResult: Equatable {
  let inputURL: URL
  let outputURL: URL
  let sourceType: String
  let bitsPerComponent: Int
  let colorSpaceName: String
  let contentHeadroom: Float
  let hasGainMap: Bool
  let mode: ConversionMode
}

enum ImageConversionError: LocalizedError, Equatable {
  case invalidQuality(Double)
  case inputDoesNotExist(String)
  case inputIsNotAFile(String)
  case unsupportedImage(String)
  case unableToDecode(String)
  case missingColorSpace
  case outputAlreadyExists(String)
  case unableToCreateOutput(String)

  var errorDescription: String? {
    switch self {
    case .invalidQuality(let quality):
      return "Compression quality must be a finite number between 0 and 1: \(quality)"
    case .inputDoesNotExist(let path):
      return "Input file does not exist: \(path)"
    case .inputIsNotAFile(let path):
      return "Input path is not a regular file: \(path)"
    case .unsupportedImage(let path):
      return "Input is not an image supported by ImageIO: \(path)"
    case .unableToDecode(let path):
      return "Unable to decode image: \(path)"
    case .missingColorSpace:
      return "Unable to create a compatible RGB color space."
    case .outputAlreadyExists(let path):
      return "Output file already exists: \(path)"
    case .unableToCreateOutput(let path):
      return "Unable to create HEIC output: \(path)"
    }
  }
}

struct ImageConverter {
  static let defaultQuality = ConstCompressionValue.def
  // Swift 6 imports kCGDefaultHDRImageContentHeadroom as mutable global
  // state. Keep the SDK's macOS 15 value locally so conversion remains
  // concurrency-safe.
  static let defaultHDRContentHeadroom: Float = 4.9261084

  let quality: Double
  private let context: CIContext
  private let fileManager: FileManager

  init(
    quality: Double = ImageConverter.defaultQuality,
    context: CIContext = CIContext(),
    fileManager: FileManager = .default
  ) {
    self.quality = quality
    self.context = context
    self.fileManager = fileManager
  }

  static func isValidQuality(_ quality: Double) -> Bool {
    quality.isFinite && (ConstCompressionValue.min...ConstCompressionValue.max).contains(quality)
  }

  static func destinationURL(for inputURL: URL) -> URL {
    inputURL.deletingPathExtension().appendingPathExtension("heic")
  }

  func convert(inputURL originalURL: URL) throws -> ConversionResult {
    guard Self.isValidQuality(quality) else {
      throw ImageConversionError.invalidQuality(quality)
    }

    let inputURL = originalURL.standardizedFileURL
    try validateInput(inputURL)

    let outputURL = Self.destinationURL(for: inputURL)
    guard !fileManager.fileExists(atPath: outputURL.path) else {
      throw ImageConversionError.outputAlreadyExists(outputURL.path)
    }

    guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      CGImageSourceGetCount(source) > 0
    else {
      throw ImageConversionError.unsupportedImage(inputURL.path)
    }

    guard let baseImage = CIImage(contentsOf: inputURL) else {
      throw ImageConversionError.unableToDecode(inputURL.path)
    }

    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let decodedImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    let bitsPerComponent =
      (properties?[kCGImagePropertyDepth] as? NSNumber)?.intValue
      ?? decodedImage?.bitsPerComponent
      ?? ConstBitValue.defaultValue
    let sourceType = (CGImageSourceGetType(source) as String?) ?? "unknown"

    let gainMap = loadGainMap(from: inputURL, source: source)
    var expandedImage =
      CIImage(
        contentsOf: inputURL,
        options: [.expandToHDR: true]
      ) ?? baseImage
    let sourceColorSpace =
      expandedImage.colorSpace ?? baseImage.colorSpace ?? decodedImage?.colorSpace
    let hasHDRColorSpace = sourceColorSpace?.isHDR() ?? false
    if expandedImage.contentHeadroom <= 1, hasHDRColorSpace {
      expandedImage =
        CIImage(
          contentsOf: inputURL,
          options: [
            .expandToHDR: true,
            .contentHeadroom: Self.defaultHDRContentHeadroom,
          ]
        ) ?? expandedImage
    }
    let headroom = expandedImage.contentHeadroom

    let mode: ConversionMode
    let temporaryOutput = temporaryURL(nextTo: outputURL, label: "encoded")
    defer { try? fileManager.removeItem(at: temporaryOutput) }

    if let gainMap {
      mode = .preservedGainMap
      let colorSpace = try sdrOutputColorSpace(for: baseImage.colorSpace ?? sourceColorSpace)
      try writeEightBitHEIC(
        image: baseImage,
        to: temporaryOutput,
        colorSpace: colorSpace,
        additionalOptions: [.hdrGainMapImage: gainMap]
      )
    } else if headroom > 1 || hasHDRColorSpace {
      mode = .generatedGainMap
      guard
        let sdrImage = CIImage(
          contentsOf: inputURL,
          options: [.toneMapHDRtoSDR: true]
        )
      else {
        throw ImageConversionError.unableToDecode(inputURL.path)
      }
      let colorSpace = try sdrOutputColorSpace(for: sdrImage.colorSpace ?? sourceColorSpace)
      try writeEightBitHEIC(
        image: sdrImage,
        to: temporaryOutput,
        colorSpace: colorSpace,
        additionalOptions: [.hdrImage: expandedImage]
      )
    } else if bitsPerComponent >= 10 {
      mode = .tenBitSDR
      let colorSpace = try outputColorSpace(for: sourceColorSpace)
      try context.writeHEIF10Representation(
        of: baseImage,
        to: temporaryOutput,
        colorSpace: colorSpace,
        options: representationOptions()
      )
    } else {
      mode = .eightBitSDR
      let colorSpace = try sdrOutputColorSpace(for: sourceColorSpace)
      try writeEightBitHEIC(
        image: baseImage,
        to: temporaryOutput,
        colorSpace: colorSpace
      )
    }

    do {
      // A hard link publishes the completed file atomically and can never
      // replace an output that appeared after the initial existence check.
      try fileManager.linkItem(at: temporaryOutput, to: outputURL)
    } catch CocoaError.fileWriteFileExists {
      throw ImageConversionError.outputAlreadyExists(outputURL.path)
    } catch {
      throw ImageConversionError.unableToCreateOutput(outputURL.path)
    }

    let colorSpaceName = sourceColorSpace?.name as String? ?? "unknown"
    return ConversionResult(
      inputURL: inputURL,
      outputURL: outputURL,
      sourceType: sourceType,
      bitsPerComponent: bitsPerComponent,
      colorSpaceName: colorSpaceName,
      contentHeadroom: headroom,
      hasGainMap: gainMap != nil,
      mode: mode
    )
  }

  private func validateInput(_ inputURL: URL) throws {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
      throw ImageConversionError.inputDoesNotExist(inputURL.path)
    }
    guard !isDirectory.boolValue else {
      throw ImageConversionError.inputIsNotAFile(inputURL.path)
    }
    let values = try? inputURL.resourceValues(forKeys: [.isRegularFileKey])
    guard values?.isRegularFile == true else {
      throw ImageConversionError.inputIsNotAFile(inputURL.path)
    }
  }

  private func loadGainMap(from inputURL: URL, source: CGImageSource) -> CIImage? {
    let index = CGImageSourceGetPrimaryImageIndex(source)
    let hasHDRGainMap =
      CGImageSourceCopyAuxiliaryDataInfoAtIndex(
        source,
        index,
        kCGImageAuxiliaryDataTypeHDRGainMap
      ) != nil
    let hasISOGainMap =
      CGImageSourceCopyAuxiliaryDataInfoAtIndex(
        source,
        index,
        kCGImageAuxiliaryDataTypeISOGainMap
      ) != nil

    guard hasHDRGainMap || hasISOGainMap else { return nil }
    return CIImage(contentsOf: inputURL, options: [.auxiliaryHDRGainMap: true])
  }

  private func representationOptions(
    additionalOptions: [CIImageRepresentationOption: Any] = [:]
  ) -> [CIImageRepresentationOption: Any] {
    var options = additionalOptions
    let qualityKey = CIImageRepresentationOption(
      rawValue: kCGImageDestinationLossyCompressionQuality as String
    )
    options[qualityKey] = quality
    return options
  }

  private func writeEightBitHEIC(
    image: CIImage,
    to outputURL: URL,
    colorSpace: CGColorSpace,
    additionalOptions: [CIImageRepresentationOption: Any] = [:]
  ) throws {
    try context.writeHEIFRepresentation(
      of: image,
      to: outputURL,
      format: .RGBA8,
      colorSpace: colorSpace,
      options: representationOptions(additionalOptions: additionalOptions)
    )
  }

  private func outputColorSpace(for source: CGColorSpace?) throws -> CGColorSpace {
    if let source,
      source.model == .rgb || source.model == .monochrome,
      source.supportsOutput
    {
      return source
    }
    guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else {
      throw ImageConversionError.missingColorSpace
    }
    return sRGB
  }

  private func sdrOutputColorSpace(for source: CGColorSpace?) throws -> CGColorSpace {
    if let source, source.isWideGamutRGB,
      let displayP3 = CGColorSpace(name: CGColorSpace.displayP3)
    {
      return displayP3
    }
    guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else {
      throw ImageConversionError.missingColorSpace
    }
    return sRGB
  }

  private func temporaryURL(nextTo outputURL: URL, label: String) -> URL {
    outputURL.deletingLastPathComponent().appendingPathComponent(
      ".img2heic-\(label)-\(UUID().uuidString).heic"
    )
  }
}
