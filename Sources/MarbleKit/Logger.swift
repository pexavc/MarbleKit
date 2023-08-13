//
//  Logger.swift
//  
//
//  Created by PEXAVC on 8/13/23.
//

import Foundation

@inline(__always) public func MarbleLog(_ message: CustomStringConvertible, logLevel: LogLevel = .warning, file: String = #file, function: String = #function, line: Int = #line) {
    if logLevel.rawValue <= MarblePlayerOptions.logLevel.rawValue {
        let fileName = (file as NSString).lastPathComponent
        print("[Marble] | \(logLevel) | \(fileName):\(line) \(function) | \(message)")
    }
}
