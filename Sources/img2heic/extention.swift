//
//  extention.swift
//  img2heic
//
//  Created by Kanae Usui on 2019/04/10.
//

import Foundation

extension String {
    
    // Get file name without extention
    func fileName() -> String {
        
        if let fileNameWithoutExtension = NSURL(fileURLWithPath: self).deletingPathExtension?.lastPathComponent {
            return fileNameWithoutExtension
        } else {
            return ""
        }
    }
    
    // Get file extention
    func fileExtension() -> String {
        
        if let fileExtension = NSURL(fileURLWithPath: self).pathExtension {
            return fileExtension
        } else {
            return ""
        }
    }
    
    // Convert the string to NSURL
    func toNsurl() -> NSURL {
        return NSURL(string: self)!
    }
    
    // Convert the string to NSURL
    func toUrl() -> URL {
        return URL(string: self)!
    }
    
    func toFileUrl() -> URL {
        return URL(fileURLWithPath: self)
    }
    
}
