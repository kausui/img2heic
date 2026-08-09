//
//  app.swift
//  img2heic
//
//  Created by Kanae Usui on 2019/04/10.
//

import ArgumentParser
import Foundation

@main
struct App: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "img2heic",
    abstract: "Convert an image to HEIC while preserving its dynamic range."
  )

  @Argument(help: "Path to an image file.")
  var filePath: String

  @Option(
    name: .shortAndLong,
    help: "Compression quality from 0 (smallest) to 1 (highest quality)."
  )
  var compress: Double = ConstCompressionValue.def

  @Option(
    name: .shortAndLong,
    help: "Output HEIC file or existing directory. Defaults to the input directory."
  )
  var output: String?

  @Flag(help: "Show image analysis and conversion details.")
  var verbose = false

  mutating func validate() throws {
    guard ImageConverter.isValidQuality(compress) else {
      throw ValidationError("--compress must be a finite number between 0 and 1.")
    }
  }

  mutating func run() throws {
    let inputURL = URL(fileURLWithPath: filePath).standardizedFileURL
    let outputURL = output.map {
      URL(fileURLWithPath: $0, isDirectory: $0.hasSuffix("/"))
        .standardizedFileURL
    }
    let converter = ImageConverter(quality: compress)
    let result = try converter.convert(inputURL: inputURL, outputURL: outputURL)

    print("ImageFile: \(result.inputURL.path)")
    if verbose {
      print("Source type: \(result.sourceType)")
      print("Bits per component: \(result.bitsPerComponent)")
      print("Color space: \(result.colorSpaceName)")
      print("HDR headroom: \(result.contentHeadroom)")
      print("Source HDR gain map: \(result.hasGainMap ? "yes" : "no")")
      print("Conversion mode: \(result.mode.rawValue)")
    }
    print("Converted to: \(result.outputURL.path)")
  }
}
