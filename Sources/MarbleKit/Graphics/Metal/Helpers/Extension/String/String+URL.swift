//
//  String+URL.swift
//  Wonder
//
//  Created by 0xKala on 8/21/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import Cocoa
#endif

extension String {
    func clearFromTemp(){
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: self) {
            do {
                try fileManager.removeItem(atPath: self)
            } catch let error {
               
            }
        }
    }
}
