//
//  CGSize.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import Cocoa
#endif

extension CGSize {
    public var isNoniPhoneXPortraitVideo: Bool {
        return self.aspect < 0.57 && (self.width < self.height)
    }
    
    public var aspect: CGFloat {
        return min(self.width, self.height) / max(self.width, self.height)
    }
    
    public var isLandscape: Bool {
        return self.width > self.height
    }
    
    public var isSquare: Bool {
        return self.width == self.height
    }
    
    public var swappedSize: CGSize{
        
        return CGSize(width: self.height, height: self.width)
    }
    
    @inline(__always)
    public var center: CGPoint {
        return CGPoint(x: width * 0.5, y: height * 0.5)
    }
    
//    public func scale(
//        to displaySize: CGSize,
//        with contentMode: UIView.ContentMode
//        ) -> CGSize {
//        let mode = ScalingMode(contentMode: contentMode)
//        return scale(to: displaySize, with: mode)
//    }
    
    public func scale(
        to displaySize: CGSize,
        with scalingMode: ScalingMode
        ) -> CGSize {
        guard
            width != 0.0,
            height != 0.0,
            displaySize.width != 0.0,
            displaySize.height != 0.0
            else {
                return CGSize(width: 1.0, height: 1.0)
        }
        let aspectWidth  = displaySize.width / width
        let aspectHeight = displaySize.height / height
        
        switch scalingMode {
        case .scaleToFill:
            return CGSize(width: aspectWidth, height: aspectHeight)
        case .scaleAspectFill:
            let scale = max(aspectWidth, aspectHeight)
            return CGSize(width: scale, height: scale)
        case .scaleAspectFit:
            let scale = min(aspectWidth, aspectHeight)
            return CGSize(width: scale, height: scale)
        default:
            return CGSize(width: 1.0, height: 1.0)
        }
    }
    
//    public func position(
//        in displaySize: CGSize,
//        with contentMode: UIView.ContentMode
//        ) -> CGRect {
//        let mode = ScalingMode(contentMode: contentMode)
//        return position(in: displaySize, with: mode)
//    }
    
    public func position(
        in displaySize: CGSize,
        with scalingMode: ScalingMode
        ) -> CGRect {
        let scale = self.scale(to: displaySize, with: scalingMode)
        let contentSize = CGSize(
            width: width * scale.width,
            height: height * scale.height)
        
        switch scalingMode {
        case .scaleToFill:
            return CGRect(origin: .zero, size: displaySize)
        case .scaleAspectFit:
            return CGRect(
                origin: CGPoint(
                    x: (displaySize.width - contentSize.width) * 0.5,
                    y: (displaySize.height - contentSize.height) * 0.5),
                size: contentSize)
        case .scaleAspectFill:
            return CGRect(
                origin: CGPoint(
                    x: (displaySize.width - contentSize.width) * 0.5,
                    y: (displaySize.height - contentSize.height) * 0.5),
                size: contentSize)
        case .center:
            return CGRect(
                origin: CGPoint(
                    x: (displaySize.width - contentSize.width) * 0.5,
                    y: (displaySize.height - contentSize.height) * 0.5),
                size: contentSize)
        case .top:
            return CGRect(
                origin: CGPoint(
                    x: (displaySize.width - contentSize.width) * 0.5,
                    y: 0.0),
                size: contentSize)
        case .bottom:
            return CGRect(
                origin: CGPoint(
                    x: (displaySize.width - contentSize.width) * 0.5,
                    y: displaySize.height - contentSize.height),
                size: contentSize)
        case .left:
            return CGRect(
                origin: CGPoint(
                    x: 0.0,
                    y: (displaySize.height - contentSize.height) * 0.5),
                size: contentSize)
        case .right:
            return CGRect(
                origin: CGPoint(
                    x: displaySize.width - contentSize.width,
                    y: (displaySize.height - contentSize.height) * 0.5),
                size: contentSize)
        case .topLeft:
            return CGRect(
                origin: .zero,
                size: contentSize)
        case .topRight:
            return CGRect(
                origin: CGPoint(
                    x: displaySize.width - contentSize.width,
                    y: 0.0),
                size: contentSize)
        case .bottomLeft:
            return CGRect(
                origin: CGPoint(
                    x: 0.0,
                    y: displaySize.height - contentSize.height),
                size: contentSize)
        case .bottomRight:
            return CGRect(
                origin: CGPoint(
                    x: displaySize.width - contentSize.width,
                    y: displaySize.height - contentSize.height),
                size: contentSize)
        }
    }
}
