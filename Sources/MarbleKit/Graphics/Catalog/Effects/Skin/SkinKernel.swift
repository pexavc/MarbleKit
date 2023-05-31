//
//  SkinKernel.swift
//  Wonder
//
//  Created by PEXAVC on 3/31/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

import Foundation
import Metal
import MetalPerformanceShaders

class SkinKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "SkinKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer,
                inputTexture : MTLTexture,
                skinTexture : MTLTexture,
                outputTexture : MTLTexture,
                threshold : Float,
                mode: Int,
                fill: Float,
                isRearCamera: Bool,
                environmentIsRunning : Bool) {
        
        var thresholdRef: Float = threshold
        var isRearRef: Float = isRearCamera ? 1.0 : 0.0
        var modeRef: Float = Float(mode)
        var fillRef: Float = Float(fill)
        
        var timeRef: Float = (Float(DispatchTime.now().uptimeNanoseconds) / 1000000000.0)
        
        var environmentRef : Float = environmentIsRunning ? 1.0 : 0.0
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        guard let thresholdBuffer = context.device.makeBuffer(
            length: MemoryLayout<Float>.size,
            options: .init(rawValue: 0)) else {
            return
        }

        memcpy(thresholdBuffer.contents(), &thresholdRef, thresholdBuffer.length)

        guard let timeBuffer = context.device.makeBuffer(
            length: MemoryLayout<Float>.size,
            options: .init(rawValue: 0)) else {
            return
        }
        memcpy(timeBuffer.contents(), &timeRef, timeBuffer.length)
        
        guard let envBuffer = context.device.makeBuffer(
            length: MemoryLayout<Float>.size,
            options: .init(rawValue: 0)) else {
            return
        }
        memcpy(envBuffer.contents(), &environmentRef, envBuffer.length)
        
        guard let modeBuffer = context.device.makeBuffer(
            length: MemoryLayout<Float>.size,
            options: .init(rawValue: 0)) else {
            return
        }
        memcpy(modeBuffer.contents(), &modeRef, modeBuffer.length)
        
        guard let fillBuffer = context.device.makeBuffer(
            length: MemoryLayout<Float>.size,
            options: .init(rawValue: 0)) else {
            return
        }
        memcpy(fillBuffer.contents(), &fillRef, fillBuffer.length)
        
        guard let isRearBuffer = context.device.makeBuffer(
            length: MemoryLayout<Float>.size,
            options: .init(rawValue: 0)) else {
            return
        }
        memcpy(isRearBuffer.contents(), &isRearRef, isRearBuffer.length)
   
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(skinTexture, index: 1)
        commandEncoder?.setTexture(outputTexture, index: 2)
        commandEncoder?.setBuffer(envBuffer, offset: 0, index: 0)
        commandEncoder?.setBuffer(thresholdBuffer, offset: 0, index: 1)
        commandEncoder?.setBuffer(timeBuffer, offset: 0, index: 2)
        commandEncoder?.setBuffer(modeBuffer, offset: 0, index: 3)
        commandEncoder?.setBuffer(fillBuffer, offset: 0, index: 4)
        commandEncoder?.setBuffer(isRearBuffer, offset: 0, index: 5)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}

extension MarbleCatalog {
    func skin(
        context: MetalContext,
        skinTexture: MTLTexture,
        threshold: Float,
        mode: Int,
        fill: Float,
        isRearCamera: Bool,
        environmentIsRunning: Bool) -> MetalFilter {
        
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                
                let outputTexture = context.device.makeTextureSimilarTo(image)

                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                    return nil
                }

                context.kernels.filters.skin.encode(commandBuffer: commandBuffer,
                                                     inputTexture: image,
                                                     skinTexture: skinTexture,
                                                     outputTexture: outputTextureCheck,
                                                     threshold: threshold,
                                                     mode: mode,
                                                     fill: fill,
                                                     isRearCamera: isRearCamera,
                                                     environmentIsRunning: environmentIsRunning)

                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()

                return outputTextureCheck
            }
        }
    }
}
