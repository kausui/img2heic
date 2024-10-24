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
struct MyApp : ParsableCommand {
    @Argument(help: "\(ConstCommandDescription.filePath)")
        var filePathStr: String
    
    @Option(name: .shortAndLong, help: "\(ConstCommandDescription.compressionLevel)")
        var compress: String?
    
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
            
            // save the image to the same directory as filename.heic
            let ciImage : CIImage = CIImage(contentsOf: sourceFileUrl)!
            
            // Get CGColorSpace from the original file
            let cgColorSpace : CGColorSpace = (ciImage.colorSpace!)
            
            // convert the file to a heic image
            do {
                print("Converting : \(filePathStr)")
                try ciContext.writeHEIFRepresentation(of: ciImage, to: destinationFilePath.toFileUrl(), format: CIFormat.RGBA8, colorSpace: cgColorSpace, options: ciContextOptions)
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
