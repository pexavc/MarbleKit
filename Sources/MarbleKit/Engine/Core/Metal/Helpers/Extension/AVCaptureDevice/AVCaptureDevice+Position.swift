//
//  AVCaptureDevice+Position.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice.Position {
    var transform: CGAffineTransform {
        switch self {
        case .front:
            return CGAffineTransform(rotationAngle: -CGFloat(Double.pi * 2)).scaledBy(x: 1, y: -1)
        case .back:
            return CGAffineTransform(rotationAngle: -CGFloat(Double.pi * 2))
        default:
            return .identity
            
        }
    }
    
    var device: AVCaptureDevice? {
        return AVCaptureDevice.devices(for: AVMediaType.video).filter {
            $0.position == self
            }.first
    }
}
