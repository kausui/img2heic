//
//  define.swift
//  img2heic
//
//  Created by Kanae Usui on 2019/04/10.
//

import Foundation

/*--------------------------------------------------------------------------------
 DEFINES
 --------------------------------------------------------------------------------*/

struct ConstCommandDefaultValue {
    static let filePath = ""
    static let compressionLevel = ConstCompressionValue.def
}

struct ConstCommandDescription {
    static let filePath = "File or Folder path."
    static let compressionLevel = "The compression level number: \(ConstCompressionValue.min) - \(ConstCompressionValue.max). \(ConstCompressionValue.max) specifies to use lossless compression. The default value is \(ConstCompressionValue.def)."
    static let outputPath = "File or Folder path for the compressed image file."
}

struct ConstBitValue {
    static let defaultValue : Int = 8
}

struct ConstExitCode {
    static let success : Int32 = 0
    static let failure : Int32 = 1
}

struct ConstCompressionValue {
    static let min : Float64 = 0.0
    static let max : Float64 = 1.0
    static let def : Float64 = 0.8
}

struct ConstFileExtension {
    static let jpg = ".jpg"
    static let heic = ".heic"
}

struct ConstMessages {
    static let osVersionError = "img2heic requires macOS version 15.0 or higher."
}

// isCompressionLevelOk checks value of compress argument
func isCompressionLevelOk( compLevel : Float64) -> Bool {
    if compLevel >= ConstCompressionValue.min && compLevel <= ConstCompressionValue.max {
        return true
    } else {
        return false
    }
}
