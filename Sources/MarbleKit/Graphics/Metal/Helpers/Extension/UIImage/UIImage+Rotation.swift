//
//  UIImage+Rotation.swift
//  Wonder
//
//  Created by 0xKala on 3/18/20.
//  Copyright © 2020 0xKala. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit

extension UIImage {
    func rotate(degrees: Float) -> UIImage? {
        return self.rotate(radians: degrees.radiansValue)
    }
    func rotate(radians: Float, fill: Bool = false) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        let flipVertical: CGAffineTransform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: newSize.width, ty: 0)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        context.concatenate(flipVertical)
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        
        let rect = CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height)
        
        if fill {
            context.setFillColor(UIColor.black.cgColor)
            context.fill(rect)
        }
        // Draw the image at its center
        
        if fill {
            self.draw(in: rect, blendMode: .normal, alpha: 1.0)
        } else {
            self.draw(in: rect)
        }

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
#endif
