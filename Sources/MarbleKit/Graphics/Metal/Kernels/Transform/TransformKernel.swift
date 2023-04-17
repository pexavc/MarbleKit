//
//  TransformKernel.swift
//  Wonder
//
//  Created by 0xKala on 8/13/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Metal
import MetalPerformanceShaders

class TransformKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    fileprivate var renderFunction : RenderFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.renderFunction = RenderFunction(
            vertexName: "TransformVertex",
            functionName: "TransformFragment",
            context: self.context,
            forcePixelFormat: .bgra8Unorm)
    }
    
    func prepareTransformedTexture(
        withInputTexture inputTexture: MTLTexture,
        transform: CGAffineTransform) -> MTLTexture? {
        let destinationSize = textureSizeForEncodeTransform(inputTexture: inputTexture,
                                                            transform: transform)
        
        guard destinationSize.width > 0 && destinationSize.height > 0 else {
            return nil
        }
        
        //Creating new texture using the obtained size
        let destinationTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: destinationSize.width,
            height: destinationSize.height,
            mipmapped: false)
        
        destinationTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        let outputTexture = self.context.device.makeTexture(descriptor: destinationTextureDescriptor)!
        
        if inputTexture.pixelFormat != renderFunction!.forcePixelFormat {
            self.renderFunction = RenderFunction(
                vertexName: "TransformVertex",
                functionName: "TransformFragment",
                context: self.context,
                forcePixelFormat: inputTexture.pixelFormat)
        }
        
        return outputTexture
    }
    
    func encode(commandBuffer : MTLCommandBuffer, inputTexture : MTLTexture, outputTexture : MTLTexture, transform: CGAffineTransform) {
        
        let p1 = CGPoint(x: -1.0, y: -1.0).applying(transform)
        let p2 = CGPoint(x: 1.0, y: -1.0).applying(transform)
        let p3 = CGPoint(x: -1.0, y: 1.0).applying(transform)
        let p4 = CGPoint(x: 1.0, y: 1.0).applying(transform)
        
        let data : [Float] = [
            Float(p1.x), Float(p1.y), 0.0, 1.0,
            Float(p2.x), Float(p2.y), 1.0, 1.0,
            Float(p3.x), Float(p3.y), 0.0, 0.0,
            Float(p4.x), Float(p4.y), 1.0, 0.0
        ]
        
        let vertexBuffer = self.context.device.makeBuffer(bytes: data,
                                             length: MemoryLayout<Float>.size * data.count,
                                             options: .cpuCacheModeWriteCombined)
        
//        var transformMatrix = simd_float3x3(float3(x: Float(transform.a), y: Float(transform.b), z: 0),
//                                            float3(x: Float(transform.c), y: Float(transform.d), z: 0),
//                                            float3(x: Float(transform.tx), y: Float(transform.ty), z: 1))
        
        //let transformBuffer = device.makeBuffer(length: MemoryLayout<simd_float3x3>.size, options: .init(rawValue: 0))!
        //memcpy(transformBuffer.contents(), &transformMatrix, transformBuffer.length)
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear//.dontCare
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        encoder?.setRenderPipelineState(self.renderFunction!.renderPipeline)
        encoder?.setFragmentTexture(inputTexture, index: 0)
        encoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        //encoder?.setVertexBuffer(transformBuffer, offset: 0, index: 1)
        encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder?.endEncoding()
    }
    
    public func textureSizeForEncodeTransform(inputTexture : MTLTexture,
                                              transform : CGAffineTransform) -> MTLSize {
        let targetSize = CGSize(width: inputTexture.width, height: inputTexture.height).applying(transform)
        return MTLSize(width: Int(abs(targetSize.width)), height: Int(abs(targetSize.height)), depth: 1)
    }
}
