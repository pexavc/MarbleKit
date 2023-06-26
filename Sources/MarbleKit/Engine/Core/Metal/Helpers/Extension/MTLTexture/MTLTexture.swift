//
//  File.swift
//  
//
//  Created by PEXAVC on 2/27/21.
//

import AVFoundation
import Foundation
import Metal

public extension MTLTexture {

    public func toFloatArray(width: Int, height: Int, featureChannels: Int) -> [Float] {
        return toArray(width: width, height: height, featureChannels: featureChannels, initial: Float(0))
    }

    func toUInt8Array(width: Int, height: Int, featureChannels: Int) -> [UInt8] {
        return toArray(width: width, height: height, featureChannels: featureChannels, initial: UInt8(0))
    }

    func toArray<T>(width: Int, height: Int, featureChannels: Int, initial: T) -> [T] {
        assert(featureChannels != 3 && featureChannels <= 4, "channels must be 1, 2, or 4")

        var bytes = [T](repeating: initial, count: width * height * featureChannels)
        let region = MTLRegionMake2D(0, 0, width, height)
        
        getBytes(&bytes, bytesPerRow: width * featureChannels * MemoryLayout<T>.stride,
                 from: region, mipmapLevel: 0)
        
        return bytes
    }
    
    var pixelBuffer: CVPixelBuffer? {
        let input = self
        
        var sourceBuffer : CVPixelBuffer?
        
        let attrs = NSMutableDictionary()
        attrs[kCVPixelBufferIOSurfacePropertiesKey] = NSMutableDictionary()
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            input.width,
                            input.height,
                            kCVPixelFormatType_32BGRA,
                            attrs as CFDictionary,
                            &sourceBuffer)
        
        guard let buffer = sourceBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let bufferPointer = CVPixelBufferGetBaseAddress(buffer)!
        
        let region = MTLRegionMake2D(0, 0, input.width, input.height)
        input.getBytes(bufferPointer, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), from: region, mipmapLevel: 0)
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}

