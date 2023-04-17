//
//  MetalImage.swift
//  Wonder
//
//  Created by 0xKala on 8/13/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Foundation
import Metal
import ImageIO
import MetalKit

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
import MobileCoreServices
#endif

public typealias Size = PixelBufferPool.Size

public enum MarbleError: Error {
    case badImage
    case somethingWentWrong
}

/* OS-specific texture provider image */
public class MetalImage {
    
    public var textureSize: Size {
        return Size(width: texture.width, height: texture.height)
    }
    
    //Texture associated with this image (not accessible outside of the framework
    let texture : MTLTexture
    
    //Restoration identifier
    fileprivate(set) var restorationIdentifier : String? = nil
    
    //Initialising with raw texture
    public init(texture : MTLTexture) {
        self.texture = texture
    }
    
    //Texture from CGImage (universal core graphics image is on iOS and on macOS)
    init(image : CGImage, context : MetalContext) throws {
        
        //We must extract it before doing any other operations on the input image file
        let sourceImageWidth : Int = image.width
        let sourceImageHeight : Int = image.height
        let sourceBPR : Int = sourceImageWidth * 4
        let sourceBPC : Int = 8
        let sourceColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let sourceBitmapInfo : CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        
        var imageData : [UInt8] = [UInt8](repeating: 0, count: sourceImageHeight * sourceImageWidth * 4)
        
        if let imageCtx : CGContext = CGContext(data: &imageData, width: sourceImageWidth, height: sourceImageHeight, bitsPerComponent: sourceBPC, bytesPerRow: sourceBPR, space: sourceColorSpace, bitmapInfo: sourceBitmapInfo.rawValue) {
            
            imageCtx.interpolationQuality = .none
            imageCtx.draw(image, in: CGRect(x: 0, y: 0, width: sourceImageWidth.cgfloat, height: sourceImageHeight.cgfloat))
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: sourceImageWidth, height: sourceImageHeight, mipmapped: false) //pixelFormat was rgba8Unorm
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            
            guard
                let texture = context.device.makeTexture(descriptor: textureDescriptor)
                else { fatalError("") }
            
            self.texture = texture
            
            let region = MTLRegionMake2D(0, 0, sourceImageWidth, sourceImageHeight)
            texture.replace(region: region, mipmapLevel: 0, withBytes:&imageData, bytesPerRow:sourceBPR)
        }
        else {
            fatalError("")
        }
        
    }
    
    //Texture from CIImage
    init(image : CIImage, context : MetalContext, ciContext : CIContext) throws {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(image.extent.width), height: Int(image.extent.height), mipmapped: false) //pixelFormat was rgba8Unorm
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        if let texture = context.device.makeTexture(descriptor: textureDescriptor) {
            self.texture = texture
        }
        else {
            fatalError("")
        }
        
        ciContext.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: image.colorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    //Creating image from URL on disk (supported on both iOS and macOS)
    convenience init(url : URL, context : MetalContext) throws {
        
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
            
            if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                try self.init(image: image, context: context)
            }
            else {
                fatalError("")
            }
        }
        else {
            fatalError("")
        }
        
    }
    
    //Initialising with UIImage (iOS only)
    #if os(iOS) || os(watchOS) || os(tvOS)
    
    public convenience init(image : MarbleImage, context : MetalContext) throws {
        guard let cgImage = image.cgImage else {
            fatalError("")
        }
        try self.init(image: cgImage, context: context)
    }
    
    #else
    
    public convenience init(image : NSImage, context : MetalContext) throws {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            try self.init(image: cgImage, context: context)
        }
        else {
            throw MarbleError.badImage
        }
    }
    
    #endif
    
}

/* Generating images from the specified texture in the POImage */
extension MetalImage {
    
    #if os(iOS) || os(watchOS) || os(tvOS)
    
    public func generateImage() -> UIImage? {
        
        if let image = generateCGImage() {
            return UIImage(cgImage: image)
        }
        else {
            return nil
        }
        
    }
    
    #else
    
    public func generateImage() -> NSImage? {
        
        if let image = generateCGImage() {
            return NSImage.init(cgImage: image, size: CGSize(width: image.width, height: image.height))
        }
        else {
            return nil
        }
        
    }
    
    #endif
    
    public func generateCIImage() -> CIImage? {
        return CIImage(mtlTexture: self.texture, options: [.colorSpace: NSNull()])
    }
    
    @objc public func generateCVPixelBuffer() -> CVPixelBuffer? {
        var sourceBuffer : CVPixelBuffer?
        
        let attrs = NSMutableDictionary()
        attrs[kCVPixelBufferIOSurfacePropertiesKey] = NSMutableDictionary()
        // 2
        CVPixelBufferCreate(kCFAllocatorDefault,
                            texture.width,
                            texture.height,
                            kCVPixelFormatType_32BGRA,
                            attrs as CFDictionary,
                            &sourceBuffer)
        
        guard let buffer = sourceBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let bufferPointer = CVPixelBufferGetBaseAddress(buffer)!
        
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(bufferPointer, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), from: region, mipmapLevel: 0)
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    public func writeToURL(_ url : URL, lossless : Bool = false) {
        
        if let image = generateCGImage() {
            
            if let destination = CGImageDestinationCreateWithURL(url as CFURL, lossless == false ? kUTTypeJPEG : kUTTypePNG, 1, nil) {
                CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality as String : 1.0] as CFDictionary)
                CGImageDestinationFinalize(destination)
                return
            }
            else {
                return
            }
            
        }
        else {
            return
        }
        
    }
    
    fileprivate func generateCGImage() -> CGImage? {
        
        //Image properties
        let imageSize = CGSize(width: texture.width, height: texture.height)
        let imageByteCount : Int = Int(imageSize.width) * Int(imageSize.height) * 4
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let bitmapInfo : CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        let renderingIntent = CGColorRenderingIntent.defaultIntent
        let bytesPerRow = Int(imageSize.width * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard imageByteCount != 0 else { return nil }
        
        //Image bytes
        //let imageBytes = calloc(Int(imageByteCount), MemoryLayout<UInt8>.size)!
        var imageBytes = [UInt8](repeating: 0, count: imageByteCount)
        
        //Getting the image region
        let region = MTLRegionMake2D(0, 0, imageSize.width.intValue, imageSize.height.intValue)
        texture.getBytes(&imageBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        //Swapping bytes for BGRA format
        if texture.pixelFormat == .bgra8Unorm {
            for i in 0..<imageByteCount/4 {
                imageBytes.swapAt(i*4 + 0, i*4 + 2)
            }
        }
        
        //Creating data provider for the extracted bytes
        if let dataProvider = CGDataProvider(data: NSData(bytes: &imageBytes, length: imageBytes.count * MemoryLayout<UInt8>.size)) {
            
            let image = CGImage(width: imageSize.width.intValue, height: imageSize.height.intValue, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: false, intent: renderingIntent)
            
            return image
            
        }
        else {
            
            return nil
        }
        
        
    }
    
}

/**
 
 */

public class PixelBufferPool {
    
    public struct Size: Hashable, Codable {
        public var width: Int
        public var height: Int
        
        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
        
        public static var zero: Size {
            return .init(width: 0, height: 0)
        }
    }
    
    public let pool: CVPixelBufferPool
    
    public let size: Size
    public let minimumBufferCount: Int
    
    public init?(
        minimumBufferCount: Int = 30,
        pixelFormatType: OSType = kCVPixelFormatType_32BGRA,
        size: Size = Size(width: 1080, height: 1920)
        ) {
        guard
            let pool = CVPixelBufferPool.create(
                minimumBufferCount: minimumBufferCount,
                pixelFormatType: pixelFormatType,
                width: size.width,
                height: size.height)
            else { return nil }
        self.minimumBufferCount = minimumBufferCount
        self.size = size
        self.pool = pool
    }
    
    public func flush(allUnused: Bool) {
        if allUnused {
            CVPixelBufferPoolFlush(pool, [.excessBuffers])
        } else {
            CVPixelBufferPoolFlush(pool, [.excessBuffers])
        }
    }
    
    public func create() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        return pixelBuffer
    }
}

extension CVPixelBufferPool {
    public func create() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, self, &pixelBuffer)
        return pixelBuffer
    }
}

