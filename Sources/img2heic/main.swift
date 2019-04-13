//
//  main.swift
//  img2heic
//
//  Created by Kanae Usui on 2019/04/10.
//

import Foundation
import Cocoa
import CoreImage
import Utility
import Basic

/*--------------------------------------------------------------------------------
  MAIN
 --------------------------------------------------------------------------------*/

if #available(OSX 10.13.4, *) {
    
    /// Base parser
    /// usage, overview are used for the help
    let parser = ArgumentParser(usage: "image_file_path.jpg --compress 0.9", overview: "img2heic is a tool for converting image files to heic files.")

    /// Arguments handling
    /// https://github.com/apple/swift-package-manager/blob/247334328570baa1e1b3c872845ff996921cedae/Sources/Basic/Path.swift
    let filepathArg = parser.add(positional: "image file path", kind: PathArgument.self, usage: ConstCommandDescription.filePath)
    
    // <options>
    let compLevelArg = parser.add(option: "--compress", shortName: "-c", kind: String.self, usage: ConstCommandDescription.compressionLevel, completion: nil)
    
    do {
        
        // Compression level default value
        var compLevelVal : Double = ConstCompressionValue.def
        
        // file path
        var filePathStr = ""
        var fileParentDirPathStr = ""
        
        // Parse command line args without the tool name
        let result = try parser.parse(Array(CommandLine.arguments.dropFirst()))
        
        // Get value of arguments(="text") from the parsed result
        if let filePath = result.get(filepathArg) {
            filePathStr = filePath.path.asString
            fileParentDirPathStr = filePath.path.parentDirectory.asString
        }
        
        // Get option value
        if let compLevelStr = result.get(compLevelArg) {
            
            let tmpCompLevelVal: Double = NSString(string: compLevelStr).doubleValue

            // verify the compression level
            if isCompressionLevelOk(compLevel:compLevelVal) == false {
                print(ConstCommandDescription.compressionLevel)
                exit(ConstExitCode.failure)
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
    } catch let error as ArgumentParserError {
        print(error.description)
    } catch {
        print(error.localizedDescription)
    }

} else {
    // Fallback on earlier versions
    print(ConstMessages.osVersionError)
    exit(ConstExitCode.failure)
}

