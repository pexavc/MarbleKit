//
//  VibesKernel.swift
//  Wonder
//
//  Created by 0xKala on 8/17/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Metal
import MetalPerformanceShaders

class VibesKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "VibesKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer, inputTexture : MTLTexture, outputTexture : MTLTexture, threshold : Float, sliderThreshold : Float) {
        
        var thresholdRef: Float = /*(Float(DispatchTime.now().uptimeNanoseconds) / 200000000.0) */ threshold
        var sliderThresholdRef: Float = sliderThreshold
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        guard let thresholdBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(thresholdBuffer.contents(), &thresholdRef, thresholdBuffer.length)
        
        guard let sliderThresholdBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(sliderThresholdBuffer.contents(), &sliderThresholdRef, sliderThresholdBuffer.length)
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(outputTexture, index: 1)
        commandEncoder?.setBuffer(thresholdBuffer, offset: 0, index: 0)
        commandEncoder?.setBuffer(sliderThresholdBuffer, offset: 0, index: 1)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}

extension MarbleCatalog {
    func vibes(context: MetalContext, threshold: Float, sliderThreshold: Float) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                    
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                    return nil
                }
                
                context.kernels.filters.vibes.encode(commandBuffer: commandBuffer,
                                                     inputTexture: image,
                                                     outputTexture: outputTextureCheck,
                                                     threshold: threshold,
                                                     sliderThreshold: sliderThreshold)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
