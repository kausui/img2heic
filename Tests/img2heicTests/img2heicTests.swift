import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import img2heic

final class Img2heicTests: XCTestCase {
  func testCompressionQualityValidation() {
    XCTAssertTrue(ImageConverter.isValidQuality(0))
    XCTAssertTrue(ImageConverter.isValidQuality(0.8))
    XCTAssertTrue(ImageConverter.isValidQuality(1))
    XCTAssertFalse(ImageConverter.isValidQuality(-0.01))
    XCTAssertFalse(ImageConverter.isValidQuality(1.01))
    XCTAssertFalse(ImageConverter.isValidQuality(.nan))
    XCTAssertFalse(ImageConverter.isValidQuality(.infinity))
  }

  func testConverterRejectsInvalidQualityWithoutCrashing() {
    let inputURL = URL(fileURLWithPath: "/tmp/not-used.png")
    XCTAssertThrowsError(try ImageConverter(quality: -1).convert(inputURL: inputURL)) {
      XCTAssertEqual($0 as? ImageConversionError, .invalidQuality(-1))
    }
  }

  func testArgumentParserRejectsInvalidCompressionValues() {
    XCTAssertThrowsError(try App.parse(["image.png", "--compress", "not-a-number"]))
    XCTAssertThrowsError(try App.parse(["image.png", "--compress", "nan"]))
    XCTAssertThrowsError(try App.parse(["image.png", "--compress", "1.1"]))
  }

  func testCLIReportsValidationFailureWithNonzeroExit() throws {
    let executable = productsDirectory.appendingPathComponent("img2heic")
    let process = Process()
    process.executableURL = executable
    process.arguments = ["image.png", "--compress", "1.1"]
    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = String(decoding: errorData, as: UTF8.self)
    XCTAssertNotEqual(process.terminationStatus, 0)
    XCTAssertTrue(errorOutput.contains("--compress must be a finite number between 0 and 1"))
  }

  func testDestinationURLHandlesSpacesUnicodeAndExtensionlessNames() {
    let withExtension = URL(fileURLWithPath: "/tmp/画像 file.name.png")
    XCTAssertEqual(
      ImageConverter.destinationURL(for: withExtension).path,
      "/tmp/画像 file.name.heic"
    )

    let withoutExtension = URL(fileURLWithPath: "/tmp/画像 file")
    XCTAssertEqual(
      ImageConverter.destinationURL(for: withoutExtension).path,
      "/tmp/画像 file.heic"
    )
  }

  func testMissingDirectoryAndNonImageErrors() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let converter = ImageConverter()

    XCTAssertThrowsError(
      try converter.convert(inputURL: directory.appendingPathComponent("missing.png"))
    ) {
      XCTAssertEqual(
        $0 as? ImageConversionError,
        .inputDoesNotExist(directory.appendingPathComponent("missing.png").path))
    }
    XCTAssertThrowsError(try converter.convert(inputURL: directory)) {
      XCTAssertEqual($0 as? ImageConversionError, .inputIsNotAFile(directory.path))
    }

    let textURL = directory.appendingPathComponent("not an image")
    try Data("hello".utf8).write(to: textURL)
    XCTAssertThrowsError(try converter.convert(inputURL: textURL)) {
      XCTAssertEqual($0 as? ImageConversionError, .unsupportedImage(textURL.path))
    }
  }

  func testEightBitSDRConversionPreservesMetadata() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let inputURL = directory.appendingPathComponent("写真 sample.jpg")
    try writeJPEG(to: inputURL, includeMetadata: true)

    let result = try ImageConverter().convert(inputURL: inputURL)
    XCTAssertEqual(result.mode, .eightBitSDR)
    XCTAssertEqual(result.outputURL.lastPathComponent, "写真 sample.heic")
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))

    let source = try XCTUnwrap(CGImageSourceCreateWithURL(result.outputURL as CFURL, nil))
    XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.heic.identifier)
    let properties = try XCTUnwrap(
      CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    )
    XCTAssertEqual((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue, 4)
    XCTAssertEqual((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue, 3)
    XCTAssertEqual((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue, 6)

    let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
    XCTAssertEqual((gps?[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue, 35.0)
  }

  func testExistingOutputIsNeverChanged() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let inputURL = directory.appendingPathComponent("image.png")
    try writePNG(to: inputURL)
    let outputURL = ImageConverter.destinationURL(for: inputURL)
    let sentinel = Data("keep me".utf8)
    try sentinel.write(to: outputURL)

    XCTAssertThrowsError(try ImageConverter().convert(inputURL: inputURL)) {
      XCTAssertEqual($0 as? ImageConversionError, .outputAlreadyExists(outputURL.path))
    }
    XCTAssertEqual(try Data(contentsOf: outputURL), sentinel)
  }

  func testTenBitSDRConversion() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let inputURL = directory.appendingPathComponent("wide-gamut.tiff")
    try writeHalfFloatTIFF(to: inputURL, colorSpaceName: CGColorSpace.extendedLinearDisplayP3)

    let result = try ImageConverter().convert(inputURL: inputURL)
    XCTAssertEqual(result.mode, .tenBitSDR)
    XCTAssertGreaterThanOrEqual(result.bitsPerComponent, 10)

    let source = try XCTUnwrap(CGImageSourceCreateWithURL(result.outputURL as CFURL, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    XCTAssertGreaterThanOrEqual(image.bitsPerComponent, 10)
  }

  func testGainMapHDRConversionPreservesGainMap() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let inputURL = directory.appendingPathComponent("adaptive-hdr.jpg")
    try writeAdaptiveHDRJPEG(to: inputURL)

    let inputSource = try XCTUnwrap(CGImageSourceCreateWithURL(inputURL as CFURL, nil))
    XCTAssertTrue(hasGainMap(inputSource))

    let result = try ImageConverter().convert(inputURL: inputURL)
    XCTAssertEqual(result.mode, .preservedGainMap)
    XCTAssertTrue(result.hasGainMap)

    let outputSource = try XCTUnwrap(CGImageSourceCreateWithURL(result.outputURL as CFURL, nil))
    XCTAssertTrue(hasGainMap(outputSource))
    let expanded = try XCTUnwrap(
      CIImage(contentsOf: result.outputURL, options: [.expandToHDR: true])
    )
    XCTAssertGreaterThan(expanded.contentHeadroom, 1)
  }

  func testHLGConversionGeneratesGainMap() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let inputURL = directory.appendingPathComponent("hlg.tiff")
    try writeHalfFloatTIFF(to: inputURL, colorSpaceName: CGColorSpace.itur_2100_HLG)

    let inputSource = try XCTUnwrap(CGImageSourceCreateWithURL(inputURL as CFURL, nil))
    XCTAssertFalse(hasGainMap(inputSource))

    let result = try ImageConverter().convert(inputURL: inputURL)
    XCTAssertEqual(result.mode, .generatedGainMap)

    let outputSource = try XCTUnwrap(CGImageSourceCreateWithURL(result.outputURL as CFURL, nil))
    XCTAssertTrue(hasGainMap(outputSource))
  }

  func testRealCameraEightAndTenBitPair() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let cases: [(name: String, expectedMode: ConversionMode, expectedDepth: Int)] = [
      ("real-sdr-8bit", .eightBitSDR, 8),
      ("real-sdr-10bit-display-p3", .tenBitSDR, 10),
    ]

    for testCase in cases {
      let inputURL = try copyFixture(named: testCase.name, to: directory)
      let result = try ImageConverter().convert(inputURL: inputURL)
      XCTAssertEqual(result.mode, testCase.expectedMode, testCase.name)
      XCTAssertEqual(result.bitsPerComponent, testCase.expectedDepth, testCase.name)

      let outputSource = try XCTUnwrap(
        CGImageSourceCreateWithURL(result.outputURL as CFURL, nil),
        testCase.name
      )
      let properties = try XCTUnwrap(
        CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any],
        testCase.name
      )
      XCTAssertEqual((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue, 6000)
      XCTAssertEqual((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue, 4000)
      XCTAssertNotNil(properties[kCGImagePropertyExifDictionary], testCase.name)
      XCTAssertGreaterThan(try averageBrightness(of: result.outputURL), 0.05, testCase.name)
    }
  }

  func testRealCameraOrientationMetadataIsPreserved() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let inputURL = try copyFixture(named: "real-orientation-8", to: directory)

    let result = try ImageConverter().convert(inputURL: inputURL)
    let outputSource = try XCTUnwrap(
      CGImageSourceCreateWithURL(result.outputURL as CFURL, nil)
    )
    let properties = try XCTUnwrap(
      CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any]
    )
    XCTAssertEqual((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue, 8)
  }

  func testProvidedIPhoneHDRPreservesGainMapAndOrientation() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fixtureURL = try XCTUnwrap(
      Bundle.module.url(forResource: "IMG_5244", withExtension: "HEIC")
    )
    let inputURL = directory.appendingPathComponent("iphone-input.heif")
    try FileManager.default.copyItem(at: fixtureURL, to: inputURL)

    let result = try ImageConverter().convert(inputURL: inputURL)
    XCTAssertEqual(result.mode, .preservedGainMap)
    XCTAssertGreaterThan(result.contentHeadroom, 1)
    XCTAssertTrue(result.hasGainMap)

    let outputSource = try XCTUnwrap(
      CGImageSourceCreateWithURL(result.outputURL as CFURL, nil)
    )
    let properties = try XCTUnwrap(
      CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any]
    )
    XCTAssertEqual((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue, 6)
    XCTAssertTrue(hasGainMap(outputSource))
    XCTAssertGreaterThan(try averageBrightness(of: result.outputURL), 0.05)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("img2heic-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func copyFixture(named name: String, to directory: URL) throws -> URL {
    let fixtureURL = try XCTUnwrap(
      Bundle.module.url(forResource: name, withExtension: "heif")
    )
    let inputURL = directory.appendingPathComponent("\(name).heif")
    try FileManager.default.copyItem(at: fixtureURL, to: inputURL)
    return inputURL
  }

  private func averageBrightness(of imageURL: URL) throws -> Double {
    let image = try XCTUnwrap(CIImage(contentsOf: imageURL))
    let average = image.applyingFilter(
      "CIAreaAverage",
      parameters: [kCIInputExtentKey: CIVector(cgRect: image.extent)]
    )
    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    var pixel = [UInt8](repeating: 0, count: 4)
    CIContext().render(
      average,
      toBitmap: &pixel,
      rowBytes: 4,
      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBA8,
      colorSpace: colorSpace
    )
    return (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3 * 255)
  }

  private var productsDirectory: URL {
    for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
      return bundle.bundleURL.deletingLastPathComponent()
    }
    fatalError("Unable to locate the SwiftPM products directory")
  }

  private func makeEightBitImage() throws -> CGImage {
    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(
      CGContext(
        data: nil,
        width: 4,
        height: 3,
        bitsPerComponent: 8,
        bytesPerRow: 4 * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ))
    context.setFillColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
    return try XCTUnwrap(context.makeImage())
  }

  private func writePNG(to url: URL) throws {
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, try makeEightBitImage(), nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
  }

  private func writeJPEG(to url: URL, includeMetadata: Bool) throws {
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    )
    var properties: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: 1.0
    ]
    if includeMetadata {
      properties[kCGImagePropertyOrientation] = 6
      properties[kCGImagePropertyExifDictionary] = [
        kCGImagePropertyExifUserComment: "img2heic metadata test"
      ]
      properties[kCGImagePropertyGPSDictionary] = [
        kCGImagePropertyGPSLatitude: 35.0,
        kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 139.0,
        kCGImagePropertyGPSLongitudeRef: "E",
      ]
    }
    CGImageDestinationAddImage(destination, try makeEightBitImage(), properties as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
  }

  private func makeHalfFloatImage(colorSpaceName: CFString) throws -> CIImage {
    let width = 4
    let height = 3
    var pixels = [Float16]()
    pixels.reserveCapacity(width * height * 4)
    for _ in 0..<(width * height) {
      pixels.append(0.75)
      pixels.append(0.5)
      pixels.append(0.25)
      pixels.append(1)
    }
    let data = pixels.withUnsafeBytes { Data($0) }
    let colorSpace = try XCTUnwrap(CGColorSpace(name: colorSpaceName))
    return CIImage(
      bitmapData: data,
      bytesPerRow: width * 4 * MemoryLayout<Float16>.size,
      size: CGSize(width: width, height: height),
      format: .RGBAh,
      colorSpace: colorSpace
    )
  }

  private func writeHalfFloatTIFF(to url: URL, colorSpaceName: CFString) throws {
    let image = try makeHalfFloatImage(colorSpaceName: colorSpaceName)
    let colorSpace = try XCTUnwrap(CGColorSpace(name: colorSpaceName))
    try CIContext().writeTIFFRepresentation(
      of: image,
      to: url,
      format: .RGBAh,
      colorSpace: colorSpace,
      options: [:]
    )
  }

  private func writeAdaptiveHDRJPEG(to url: URL) throws {
    let baseCGImage = try makeEightBitImage()
    let baseImage = CIImage(cgImage: baseCGImage)
    let hdrImage = try makeHDRImage()
    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let qualityKey = CIImageRepresentationOption(
      rawValue: kCGImageDestinationLossyCompressionQuality as String
    )
    try CIContext().writeJPEGRepresentation(
      of: baseImage,
      to: url,
      colorSpace: colorSpace,
      options: [qualityKey: 1.0, .hdrImage: hdrImage]
    )
  }

  private func makeHDRImage() throws -> CIImage {
    let width = 4
    let height = 3
    var pixels = [Float16]()
    pixels.reserveCapacity(width * height * 4)
    for _ in 0..<(width * height) {
      pixels.append(2.0)
      pixels.append(1.25)
      pixels.append(0.5)
      pixels.append(1)
    }
    let data = pixels.withUnsafeBytes { Data($0) }
    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3))
    return CIImage(
      bitmapData: data,
      bytesPerRow: width * 4 * MemoryLayout<Float16>.size,
      size: CGSize(width: width, height: height),
      format: .RGBAh,
      colorSpace: colorSpace
    )
  }

  private func hasGainMap(_ source: CGImageSource) -> Bool {
    let index = CGImageSourceGetPrimaryImageIndex(source)
    return CGImageSourceCopyAuxiliaryDataInfoAtIndex(
      source,
      index,
      kCGImageAuxiliaryDataTypeHDRGainMap
    ) != nil
      || CGImageSourceCopyAuxiliaryDataInfoAtIndex(
        source,
        index,
        kCGImageAuxiliaryDataTypeISOGainMap
      ) != nil
  }
}
