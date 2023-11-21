//
//  BokehKernel.swift
//  Wonder
//
//  Created by PEXAVC on 1/10/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

import Metal
import MetalPerformanceShaders

class BlurKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "BlurKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer,
                inputTexture : MTLTexture,
                outputTexture : MTLTexture,
                threshold : Float) {//radius
        
        var thresholdRef: Float = threshold
        var timeRef: Float = 0.0//(Float(DispatchTime.now().uptimeNanoseconds) / 20000000.0)
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        guard let timeBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(timeBuffer.contents(), &timeRef, timeBuffer.length)
        
        guard let thresholdBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(thresholdBuffer.contents(), &thresholdRef, thresholdBuffer.length)
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(outputTexture, index: 1)
        commandEncoder?.setBuffer(timeBuffer, offset: 0, index: 0)
        commandEncoder?.setBuffer(thresholdBuffer, offset: 0, index: 1)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}

extension MarbleCatalog {
    func blur(context: MetalContext, threshold: Float) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                    return nil
                }
                
                context.kernels.filters.blur.encode(commandBuffer: commandBuffer,
                                                     inputTexture: image,
                                                     outputTexture: outputTextureCheck,
                                                     threshold: threshold)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
