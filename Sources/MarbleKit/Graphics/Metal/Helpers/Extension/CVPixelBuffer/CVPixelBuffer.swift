//
//  CVPixelBuffer.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
import AVFoundation
import Metal

extension CVPixelBufferPool {
    static func create(
        minimumBufferCount: Int = 30,
        pixelFormatType: OSType = kCVPixelFormatType_32BGRA,
        width: Int = 1080,
        height: Int = 1920
        ) -> CVPixelBufferPool?
    {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String : minimumBufferCount
        ]
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary, &pool)
        return pool
    }
}

extension CVImageBuffer {
    
    var isPlanar: Bool {
        return CVPixelBufferIsPlanar(self)
    }
    
    func texture(
        from cache: CVMetalTextureCache,
        planeIndex: Int = 0,
        pixelFormat: MTLPixelFormat = .bgra8Unorm
        ) -> MTLTexture?
    {
        let width: Int, height: Int
        if isPlanar {
            width = CVPixelBufferGetWidthOfPlane(self, planeIndex)
            height = CVPixelBufferGetHeightOfPlane(self, planeIndex)
        } else {
            width = CVPixelBufferGetWidth(self)
            height = CVPixelBufferGetHeight(self)
        }
        
        var metalTexture: CVMetalTexture? = nil
        
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache,
            self, nil, pixelFormat,
            width, height,
            planeIndex, &metalTexture)
        
        guard
            result == kCVReturnSuccess,
            let cvTexture = metalTexture,
            let texture = CVMetalTextureGetTexture(cvTexture)
            else { return nil }
        
        return texture
        
    }
}
