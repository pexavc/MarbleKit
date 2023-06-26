//
//  MetalContext.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import SwiftUI

public enum MarbleUXEvent {
    case began
    case changed
    case failed
    case cancelled
    case possible
    case ended
}

#if os(iOS)
extension UIGestureRecognizer.State {
    public var asMarbleEvent: MarbleUXEvent {
        switch self {
        case .began:
            return .began
        case .changed:
            return .changed
        case .cancelled:
            return .cancelled
        case .possible:
            return .possible
        case .ended:
            return .ended
        default:
            return .failed
        }
    }
}
#elseif os(OSX)
extension NSGestureRecognizer.State {
    public var asMarbleEvent: MarbleUXEvent {
        switch self {
        case .began:
            return .began
        case .changed:
            return .changed
        case .cancelled:
            return .cancelled
        case .possible:
            return .possible
        case .ended:
            return .ended
        default:
            return .failed
        }
    }
}
public extension NSMagnificationGestureRecognizer {
    public var scale: CGFloat {
        self.magnification
    }
}
#endif

public protocol MarbleKernel {
    
}

//Execution context closure
public typealias ContextCommandsSet = ((_ commandBuffer : MTLCommandBuffer) throws -> Void)

public class MetalContext {
    
    public struct Kernels {
        
//        fileprivate(set) var copy : CopyKernel!
        public var downsample : DownsampleKernel!
        public var paddedDownsample : PaddedDownsampleKernel!
        public var transform : TransformKernel!
        public var watermark : WatermarkKernel!
        
        public struct Filters {
            fileprivate(set) var analog : AnalogKernel!
            fileprivate(set) var drive : DriveKernel!
            fileprivate(set) var ink : InkKernel!
            fileprivate(set) var vibes : VibesKernel!
            fileprivate(set) var bokeh : BokehKernel!
            fileprivate(set) public var depth : DepthKernel!
            fileprivate(set) var backdrop : BackdropKernel!
            fileprivate(set) var skinDecolor : SkinDecolorKernel!
            fileprivate(set) var skin : SkinKernel!
            fileprivate(set) var polka : PolkaKernel!
            fileprivate(set) var stars : StarsKernel!
            fileprivate(set) var pixels : PixelKernel!
            fileprivate(set) var disco : DiscoKernel!
            fileprivate(set) var godRay : GodRayKernel!
            
            fileprivate mutating func setup(in context: MetalContext) {
                analog = AnalogKernel(context: context)
                drive = DriveKernel(context: context)
                ink = InkKernel(context: context)
                vibes = VibesKernel(context: context)
                bokeh = BokehKernel(context: context)
                depth = DepthKernel(context: context)
                backdrop = BackdropKernel(context: context)
                skinDecolor = SkinDecolorKernel(context: context)
                skin = SkinKernel(context: context)
                polka = PolkaKernel(context: context)
                stars = StarsKernel(context: context)
                pixels = PixelKernel(context: context)
                disco = DiscoKernel(context: context)
                godRay = GodRayKernel(context: context)
            }
        }
//        fileprivate(set) var bgr2rgb : BGR2RGBKernel!
        
        fileprivate(set) public var filters = Filters()
//
        fileprivate mutating func setup(in context: MetalContext) {
//            copy = CopyKernel(context: context)
            downsample = DownsampleKernel(context: context)
            paddedDownsample = PaddedDownsampleKernel(context: context)
            transform = TransformKernel(context: context)
            watermark = WatermarkKernel(context: context)
//            bgr2rgb = BGR2RGBKernel(context: context)
            
            filters.setup(in: context)
        }
    }
    
    //Each context has a device associated with it
    public let device : MTLDevice
    
    let coreImageContext : CIContext
    
    //Textures cache
    let textureCache : TextureCache
    
    //Buffers cache
    let buffersCache : BufferCache
    
    //Single-used kernels
    public var kernels : Kernels = Kernels()
    
    //Each context has a default library associated with the context
    let library : MTLLibrary
    
    //Loader of textures
    let loader : MTKTextureLoader
    
    var mtlRenderPass: MTLRenderPassDescriptor?
    
    //Command queue associated with the current context
    public let commandQueue : MTLCommandQueue
    
    //Private command buffer initialisation
    internal var commandBuffer : MTLCommandBuffer?
    
    //Total execution time
    private var totalExecutionTime : CFAbsoluteTime = 0
    
    //Initialising the context. Can be initialised from scratch or using the parameters of the existing context.
    public required init(context : MetalContext? = nil) {
        
        
        if let context = context {
            self.device = context.device
            self.library = context.library
            self.commandQueue = context.commandQueue
        }
        else {
            if let device = MTLCreateSystemDefaultDevice() {
                self.device = device
                self.commandQueue = device.makeCommandQueue()!
                self.library = (try? device.makeDefaultLibrary(bundle: Bundle.module)) ?? device.makeDefaultLibrary()!
//                do {
//                    self.library = try device.makeDefaultLibrary()//(filepath: Bundle(for: MetalContext.self).url(forResource: "default", withExtension: "metallib")!.path)
//                } catch {
//                    fatalError("Failed to initialise default Metal library.")
//                }
            }
            else {
                fatalError("Failed to initialise Metal device.")
            }
        }
        
        self.coreImageContext = CIContext(mtlDevice: self.device)
        self.loader = MTKTextureLoader(device: device)
        self.textureCache = TextureCache(device: device)
        self.buffersCache = BufferCache(device: device)
        
        kernels.setup(in: self)
    }
    
    public func begin() {
        commandBuffer = commandQueue.makeCommandBuffer()
    }
    
    //Executing number of commands on the device
    public func execute(_ label : String, commands : ContextCommandsSet) throws {
        
        if let commandBuffer = self.commandBuffer {
            //Command buffer label
            commandBuffer.label = label
            
            try commands(commandBuffer)
        }
        
    }
    
    public func end() {
        if let commandBuffer = self.commandBuffer {
            //let startTime = CACurrentMediaTime()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            //let elapsedTime = CACurrentMediaTime() - startTime
            //print("Command buffer done in \(1/elapsedTime).")
        }
    }
    
    public func resetTotalExecutionTime() {
        totalExecutionTime = 0
    }
}


class TextureCache {
    
    //All buffers are named and initially assigned
    fileprivate var textures = [String : MTLTexture]()
    
    //Private device that is used to allocate new buffers
    fileprivate unowned let device : MTLDevice
    
    init(device : MTLDevice) {
        self.device = device
    }
    
}

/**
 
 */

extension TextureCache {
    
    @discardableResult
    public func makeTextureWithName(_ name : String, descriptor : MTLTextureDescriptor) throws -> MTLTexture {
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("")
//            throw PORuntimeError.textureCreationFailed
        }
        
        textures[name] = texture
        return texture
    }
    
    @discardableResult
    public func makeTextureWithName(_ name : String, similarTexture : MTLTexture) throws -> MTLTexture {
        
        guard let texture = device.makeTextureSimilarTo(similarTexture) else {
            fatalError("")
        }
        
        textures[name] = texture
        return texture
    }
    
    func textureWithName(_ name : String) -> MTLTexture? {
        return textures[name]
    }
    
    func setTextureWithName(_ name: String, texture : MTLTexture) {
        textures[name] = texture
    }
    
    func removeTextureWithName(_ name: String) {
        textures[name] = nil
    }
    
    func removeAllTextures() {
        textures.removeAll()
    }
    
}

/**
 
 */

class BufferCache {
    
    //All buffers are named and initially assigned
    fileprivate var buffers = [String : MTLBuffer]()
    
    //Private device that is used to allocate new buffers
    fileprivate unowned let device : MTLDevice
    
    init(device : MTLDevice) {
        self.device = device
    }
    
}

extension BufferCache {
    
    //Allocating new buffer with the specified name
    func bufferWithName(_ name : String, size : Int) throws -> MTLBuffer {
        guard let buffer = buffers[name] else {
            guard let buffer = device.makeBuffer(length: size, options: [.cpuCacheModeWriteCombined]) else {
                fatalError("")
            }
            buffers[name] = buffer
            return buffer
        }
        return buffer
    }
    
    func removeBufferWithName(_ name: String) {
        buffers[name] = nil
    }
    
    func removeAllBuffers() {
        buffers.removeAll()
    }
    
}
