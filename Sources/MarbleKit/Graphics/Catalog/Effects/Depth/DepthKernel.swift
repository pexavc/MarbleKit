//
//  DepthKernel.swift
//  Wonder
//
//  Created by PEXAVC on 1/2/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

import AVFoundation
import Metal
import MetalKit
import MetalPerformanceShaders

public class DepthKernel: MarbleKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    fileprivate var renderPipelineState: MTLRenderPipelineState?
    fileprivate var depthStencilState: MTLDepthStencilState?
    
    let camera: Camera = Camera()
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "DepthKernel", context: self.context)
        
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = context.library.makeFunction(name: "vertexShaderPoints")
        renderPipelineStateDescriptor.fragmentFunction = context.library.makeFunction(name: "fragmentShaderPoints")
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
//        renderPipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
//        renderPipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
//        renderPipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
//        renderPipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
//        renderPipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.depth32Float

        let depthStencilStateDescriptor: MTLDepthStencilDescriptor = .init()
        depthStencilStateDescriptor.isDepthWriteEnabled = true
        depthStencilStateDescriptor.depthCompareFunction = .less
        
        depthStencilState = context.device.makeDepthStencilState(descriptor: depthStencilStateDescriptor)
        
        do {
            renderPipelineState = try context.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        } catch {
            fatalError("")
        }
    }
    
    public func updateCameraPan(startingPan: Int, res: CGSize) {
        camera.start(res)
        camera.updatePan(startingPan)
    }
    
    public func updateStartingZoom(startingZoom: Float) {
        camera.updateZoom(startingZoom)
    }
    
    func encode(commandBuffer : MTLCommandBuffer,
                inputTexture : MTLTexture,
                depthPayload : MarbleCatalog.DepthPayload?,
                skinPayload : MarbleCatalog.SkinPayload?,
                outputTexture : MTLTexture,
                threshold : Float) {
        
        guard let payload = depthPayload,
              let depthTexture = depthPayload?.depthDataMap else { return }
        
        //////
        let drawableSize: CGSize = payload.environment.drawableSize
        let inputSize: CGSize = .init(width: (inputTexture.width), height: (inputTexture.height))
        let trueDepthSize: CGSize = .init(width: depthTexture.width, height: depthTexture.height)
        ///
        
        //DEV:
        let skinMode: Int = 1
        let isSkin: Bool = skinPayload != nil
        //
        
        updateCamera(withSize: drawableSize,
                     withTextureSize: inputTexture.size,
                     orientation: .init(
                        isLandscapeLeft: (
                            payload.environment.isLandscapeLeft &&
                                !payload.environment.isRearCamera),
                        isLandscapeRight: (
                            payload.environment.isLandscapeRight &&
                                !payload.environment.isRearCamera)),
                     isRearCamera: payload.environment.isRearCamera)
        updateGestures(
            depthPayload?.environment.gestures)
        
        if payload
            .environment
            .actions
            .isRestarting {
            camera.restartAnimation()
        }
        
        //////
        let gThreshold = 0.012//depthPayload?.environment.gestures.threshold ?? 0.0
        var isLandscapeRef: Float = inputTexture.size.isLandscape ? 1.0 : 0.0
        var skinModeRef: Float = Float(skinMode)
        var thresholdRef: Float =  6000 - ((6000)*Float(1.0 - gThreshold))
        var thresholdRefSample: Float = threshold
        var sizeWidth: Float = Float(depthTexture.width)
        var sizeHeight: Float = Float(depthTexture.height)
        
        let projection = camera.getProjection()
        var matrix = projection.matrix
        let matrixZ = projection.z
        //////
        guard let isLandscapeBuffer = context.device.makeBuffer(
                length: MemoryLayout<Float>.size,
                options: .init(rawValue: 0)) else {
            return
        }
        memcpy(isLandscapeBuffer.contents(), &isLandscapeRef, isLandscapeBuffer.length)
        
        guard let thresholdBuffer = context.device.makeBuffer(
                length: MemoryLayout<Float>.size,
                options: .init(rawValue: 0)) else {
            return
        }
        memcpy(thresholdBuffer.contents(), &thresholdRef, thresholdBuffer.length)
        
        guard let skinModeBuffer = context.device.makeBuffer(
                length: MemoryLayout<Float>.size,
                options: .init(rawValue: 0)) else {
            return
        }
        memcpy(skinModeBuffer.contents(), &skinModeRef, skinModeBuffer.length)
       
        
        guard let renderPipelineState = self.renderPipelineState,
              let depthStencilState = self.depthStencilState else {
                return
        }
        
        // Compute kernel
        let depthTextureDescriptor: MTLTextureDescriptor = .init()
        depthTextureDescriptor.width = Int(inputSize.width)
        depthTextureDescriptor.height = Int(inputSize.height)
        depthTextureDescriptor.pixelFormat = MTLPixelFormat.depth32Float
        depthTextureDescriptor.usage = .renderTarget
        
        #if (arch(i386) || arch(x86_64))
        depthTextureDescriptor.storageMode = .private
        #endif
        
        let depthTestTexture = context.device.makeTexture(
            descriptor: depthTextureDescriptor)
        
        // Vertex and fragment shaders
        let renderPassDescriptor: MTLRenderPassDescriptor = .init()
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.depthAttachment.texture = depthTestTexture
        
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        
        let renderEncoder  = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor)
        renderEncoder?.setDepthStencilState(depthStencilState)
        renderEncoder?.setRenderPipelineState(renderPipelineState)
        
        renderEncoder?.setVertexBytes(
            &matrix,
            length: MemoryLayout.size(ofValue: matrix),
            index: 0)
        renderEncoder?.setVertexBytes(
            &thresholdRefSample,
            length: MemoryLayout.size(ofValue: thresholdRefSample),
            index: 1)
        renderEncoder?.setVertexBytes(
            &isLandscapeRef,
            length: MemoryLayout.size(ofValue: isLandscapeRef),
            index: 2)
        renderEncoder?.setVertexBytes(
            &skinModeRef,
            length: MemoryLayout.size(ofValue: skinModeRef),
            index: 3)
        renderEncoder?.setVertexBytes(
            &matrix,
            length: MemoryLayout.size(ofValue: matrixZ),
            index: 4)
        renderEncoder?.setVertexBytes(
            &sizeWidth,
            length: MemoryLayout.size(ofValue: sizeWidth),
            index: 5)
        renderEncoder?.setVertexBytes(
            &sizeHeight,
            length: MemoryLayout.size(ofValue: sizeHeight),
            index: 6)
        renderEncoder?.setVertexTexture(
            depthTexture, index: 0)
        renderEncoder?.setFragmentTexture(
            inputTexture, index: 0)
        renderEncoder?.setFragmentTexture(
            skinPayload?.skinTexture, index: 1)
        renderEncoder?.setFragmentBuffer(
            thresholdBuffer, offset: 0, index: 0)
        renderEncoder?.setFragmentBuffer(
            isLandscapeBuffer, offset: 0, index: 1)
        renderEncoder?.drawPrimitives(
            type: .point,
            vertexStart: 0,
            vertexCount: Int(trueDepthSize.width * trueDepthSize.height))
        renderEncoder?.endEncoding()
    }
}

extension DepthKernel: CameraDelegate {
    func updateGestures(
        _ gestures: MarbleCatalog.Environment.Gestures?) {
        
        guard let gestures = gestures else { return }
        
        #if os(macOS)
        updateScroll(gestures.scroll.0, scale: gestures.scroll.1)
        #else
        updatePinch(gestures.pinch.0, scale: gestures.pinch.1)
        updateRotate(gestures.rotate.0, rotation: gestures.rotate.1)
        #endif
        
        updatePan(gestures.pan.0, point: gestures.pan.1)
        updateTap(gestures.tap)
    }
    
    func updatePinch(
        _ gesture: MarbleUXEvent?,
        scale: CGFloat) {
        guard gesture != nil else {
            return }
        
        camera.moveTowardCenter(Float(scale))
    }
    
    func updateScroll(
        _ gesture: MarbleUXEvent?,
        scale: CGFloat) {
        guard gesture != nil else {
            return }
        
        camera.moveTowardCenter(Float(scale))
    }
    
    func updatePan(_ gesture: MarbleUXEvent?,
                   point: CGPoint) {
        guard gesture != nil else { return }
        
        
        
        #if os(macOS)
        camera.rollAroundCenter(.init(x: point.x, y: -point.y))
        #else
        camera.rollAroundCenter(.init(x: point.x, y: point.y))
        #endif
    }
    
    func updateTap(_ gesture: MarbleUXEvent?) {
        guard gesture != nil else { return }
//        camera.reset()
    }
    
    func updateRotate(_ gesture: MarbleUXEvent?, rotation: CGFloat) {
        guard gesture != nil else { return }
        camera.rotateAroundCenter(Float(rotation))
    }
    
    func updateCamera(
        withSize size: CGSize,
        withTextureSize textureSize: CGSize,
        orientation: Camera.Properties.Orientation,
        isRearCamera: Bool) {
        
        camera.updateOrientation(
            .init(
                isLandscapeLeft: orientation.isLandscapeLeft,
                isLandscapeRight: orientation.isLandscapeRight),
            textureIsLandscape: textureSize.isLandscape)
        camera.updateDeviceCamera(isRearCamera)
        
        guard camera.isReady else {
            camera.start(size)
            return
            
        }
        
        camera.animate()
    }
}

extension MarbleCatalog {
    
    public struct DepthPayload {
        public var depthDataMap: MTLTexture?
        public var currentDepthMarbleTexture: MTLTexture?
        public var depthCenter: Float? = nil
        
        public var environment: MarbleCatalog.Environment
        
        public init(
            depthDataMap: MTLTexture?,
            currentDepthMarbleTexture: MTLTexture? = nil,
            depthCenter: Float? = nil,
            environment: MarbleCatalog.Environment) {
            
            self.depthDataMap = depthDataMap
            self.currentDepthMarbleTexture = currentDepthMarbleTexture
            self.depthCenter = depthCenter
            self.environment = environment
        }
    }
    
    func depth(context: MetalContext,
               depthPayload: DepthPayload,
               skinPayload: SkinPayload? = nil,
               threshold: Float = 1.0) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context
                        .commandQueue
                        .makeCommandBuffer(),
                      let outputTextureCheck = outputTexture else {
                    return nil
                }
                
                context.kernels.filters.depth.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: image,
                    depthPayload: depthPayload,
                    skinPayload: skinPayload,
                    outputTexture: outputTextureCheck,
                    threshold: threshold)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
