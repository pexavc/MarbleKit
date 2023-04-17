//
//  InkKernel.swift
//  Wonder
//
//  Created by 0xKala on 8/14/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Metal
import MetalPerformanceShaders

class InkKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "InkKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer, inputTexture : MTLTexture, outputTexture : MTLTexture, threshold : Float) {
        
        /**
         
            0.1 - 0.2 showcases a a strong intensity
                values of maxes of 1.5-2.0 seem to be closest to this
                constant division to showcase the intensity appropritiately
         
         */
        var thresholdRef: Float = 0.12/threshold
        
        if thresholdRef > 1.2 {
            thresholdRef = 0.75
        }
        
        if thresholdRef < 0.16 {
            thresholdRef = 0.16
        }
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        guard let thresholdBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(thresholdBuffer.contents(), &thresholdRef, thresholdBuffer.length)
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(outputTexture, index: 1)
        commandEncoder?.setBuffer(thresholdBuffer, offset: 0, index: 0)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}

extension MarbleCatalog {
    func ink(context: MetalContext, threshold: Float) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                        return nil
                }
                
                context.kernels.filters.ink.encode(commandBuffer: commandBuffer, inputTexture: image, outputTexture: outputTextureCheck, threshold: threshold)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
