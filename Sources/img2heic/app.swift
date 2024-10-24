//
//  main.swift
//  img2heic
//
//  Created by Kanae Usui on 2019/04/10.
//

import Foundation
import Cocoa
import CoreImage
import ArgumentParser

@main
struct App : ParsableCommand {
    @Argument(help: "\(ConstCommandDescription.filePath)")
        var filePathStr: String
    
    @Option(name: .shortAndLong, help: "\(ConstCommandDescription.compressionLevel)")
        var compress: String?
    
    @Flag(help: "show detail logs")
        var verbose: Bool = false
    
    mutating func run() throws {
        if #available(OSX 15.0, *) {
            // Compression level default value
            var compLevelVal : Double = ConstCompressionValue.def
            
            // file path
            let filePathUrl = filePathStr.toUrl()
            let fileParentDirPathStr = filePathUrl.deletingLastPathComponent().path
            
            // Get option value
            if let compress {
                let tmpCompLevelVal: Double = NSString(string: compress).doubleValue
                // verify the compression level
                if isCompressionLevelOk(compLevel:compLevelVal) == false {
                    print(ConstCommandDescription.compressionLevel)
                    throw NSError(domain: "Invalid Option", code: -1, userInfo: nil)
                }
                compLevelVal = tmpCompLevelVal
            }
            
            // COMPRESS start
            let ciContextOptions = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): compLevelVal]
            
            let sourceFileUrl = filePathStr.toFileUrl()
            
            print("ImageFile: \(filePathStr)")
            //File name and path
            let sourceFilePathWithoutExt = fileParentDirPathStr + "/" + filePathStr.fileName()
            let destinationFilePath = sourceFilePathWithoutExt + ConstFileExtension.heic
            
            // Determine file type
            let fileExtension = filePathStr.fileExtension()
            let uti = UTTypeCreatePreferredIdentifierForTag( kUTTagClassFilenameExtension, fileExtension as CFString, nil)
            if UTTypeConformsTo((uti?.takeRetainedValue())!, kUTTypeImage) {
            } else {
                // Nothing to do
                print("File is not image:\(filePathStr).")
                throw NSError(domain: "Invalid File", code: -1, userInfo: nil)
            }
            
            // new CIContext
            let ciContext : CIContext = CIContext(options: nil)

            // get image bit per component
            var bitsPerComponent = ConstBitValue.defaultValue
            guard let imageSource = CGImageSourceCreateWithURL(sourceFileUrl as CFURL, nil) else {
                throw NSError(domain: "Invalid File", code: -1, userInfo: nil)
            }
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw NSError(domain: "Image process failure", code: -1, userInfo: nil)
            }
            
            bitsPerComponent = cgImage.bitsPerComponent
            
            if verbose {
                print("Bits per pixel: \(cgImage.bitsPerPixel)")
                print("Bits per component: \(bitsPerComponent)")
            }
            
            let ciImage : CIImage = CIImage(cgImage: cgImage)
            
            // Get CGColorSpace from the original file
            let cgColorSpace : CGColorSpace = (ciImage.colorSpace!)
            
            // convert the file to a heic image
            // 10 or more bit color file is converted to HEIF10
            do {
                print("Converting : \(filePathStr)")
                if bitsPerComponent >= 10 {
                    try ciContext.writeHEIF10Representation(of: ciImage, to: destinationFilePath.toFileUrl(), colorSpace: cgColorSpace, options: ciContextOptions)
                } else {
                    try ciContext.writeHEIFRepresentation(of: ciImage, to: destinationFilePath.toFileUrl(), format: CIFormat.RGBA8, colorSpace: cgColorSpace, options: ciContextOptions)
                }
                print("Converted to : " + destinationFilePath)
            } catch {
                print("Failed to convert. File:\(filePathStr) \n Error:\(error)")
            }
        } else {
            // Fallback on earlier versions
            print(ConstMessages.osVersionError)
            throw NSError(domain: "OS Version", code: -1, userInfo: nil)
        }
    }
}
