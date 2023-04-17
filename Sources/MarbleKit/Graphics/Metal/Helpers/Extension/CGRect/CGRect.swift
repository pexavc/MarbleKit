//
//  CGRect.swift
//  Wonder
//
//  Created by 0xKala on 8/13/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import Cocoa
#endif

extension CGRect {
    
    @inline(__always)
    public var rounded: CGRect {
        return CGRect(
            x: round(origin.x),
            y: round(origin.y),
            width: round(size.width),
            height: round(size.height))
    }
}
