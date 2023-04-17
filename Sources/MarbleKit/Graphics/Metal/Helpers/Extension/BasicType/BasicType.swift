//
//  BasicType.swift
//  Wonder
//
//  Created by 0xKala on 8/13/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#endif

/* Numbers */
extension Double{
    
    public var intValue : Int{
        
        get {
            return Int(self)
        }
        
        set(newValue) {
            self = Double(newValue)
        }
    }
    
    public var floatValue : Float {
        
        get {
            return Float(self)
        }
        
        set(newValue) {
            self = Double(newValue)
        }
    }
    
    public var cgfloatValue : CGFloat {
        
        get {
            return CGFloat(self)
        }
        
        set(newValue) {
            self = Double(newValue)
        }
    }
    
}

extension Float {
    
    public var doubleValue : Double {
        
        get {
            return Double(self)
        }
        
        set(newValue) {
            self = Float(newValue)
        }
        
    }
    
    public var intValue : Int {
        
        get {
            return self.isFinite ? Int(self) : Int.max
        }
        
        set(newValue) {
            self = Float(newValue)
        }
        
    }
    
    public var uintValue : UInt32 {
        
        get {
            return self.isFinite ? UInt32(self) : UInt32.max
        }
        
        set(newValue) {
            self = Float(newValue)
        }
        
    }
    
    public var cgfloatValue : CGFloat {
        
        get {
            return CGFloat(self)
        }
        
        set(newValue) {
            self = Float(newValue)
        }
        
    }
    
}

extension Float {
    
    //Convert number to degrees
    public var degreesValue : Float {
        return self * (180 / Double.pi.floatValue)
    }
    
    //Convert degrees to radians
    public var radiansValue : Float {
        return self * (Double.pi.floatValue / 180)
    }
}

extension Int {
    
    public var doubleValue : Double {
        
        get {
            return Double(self)
        }
        
        set(newValue) {
            self = Int(newValue)
        }
        
    }
    
    public var floatValue : Float {
        
        get {
            return Float(self)
        }
        
        set(newValue) {
            self = Int(newValue)
        }
        
    }
    public var cgfloat:CGFloat {
        
        get {
            return CGFloat(self)
        }
        
        set(newValue) {
            self = Int(newValue)
        }
        
    }
}

extension UInt8 {
    
    public var doubleValue : Double {
        
        get {
            return Double(self)
        }
        
        set(newValue) {
            self = UInt8(newValue)
        }
        
    }
    
    public var floatValue : Float {
        
        get {
            return Float(self)
        }
        
        set(newValue) {
            self = UInt8(newValue)
        }
        
    }
    public var cgfloat:CGFloat {
        
        get {
            return CGFloat(self)
        }
        
        set(newValue) {
            self = UInt8(newValue)
        }
        
    }
}

extension CGFloat {
    
    public var floatValue : Float {
        
        get {
            return Float(self)
        }
        
        set(newValue) {
            self = CGFloat(newValue)
        }
    }
    
    public var intValue : Int {
        
        get {
            return Int(self)
        }
        
        set(newValue) {
            self = CGFloat(newValue)
        }
        
    }
    
    public var degrees: CGFloat {
      return self * (180.0 / .pi)
    }

    public var radians: CGFloat {
      return self / 180.0 * .pi
    }
}

/* String sanitisation */
extension String {
    
    public var stringByRemovingWhiteSpaceCharacters : String {
        return self.components(separatedBy: CharacterSet.init(charactersIn: " \n\t")).joined(separator: "")
    }
    
}

