//
//  MetallicKernel.swift
//  Wonder
//
//  Created by PEXAVC on 3/31/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

import Foundation
import Metal
import MetalPerformanceShaders

class PolkaKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "PolkaKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer,
                inputTexture : MTLTexture,
                outputTexture : MTLTexture,
                threshold : Float,
                sliderValue : Float) {
        
        var timeRef: Float = (Float(DispatchTime.now().uptimeNanoseconds) / 1000000000.0) // threshold
        var thresholdRef: Float = threshold
        var sliderRef: Float = sliderValue
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        guard let thresholdBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        
        guard let timeBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        
        guard let sliderBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }

        memcpy(thresholdBuffer.contents(), &thresholdRef, thresholdBuffer.length)
        memcpy(timeBuffer.contents(), &timeRef, timeBuffer.length)
        memcpy(sliderBuffer.contents(), &sliderRef, sliderBuffer.length)

        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(outputTexture, index: 1)
        commandEncoder?.setBuffer(timeBuffer, offset: 0, index: 0)
        commandEncoder?.setBuffer(thresholdBuffer, offset: 0, index: 1)
        commandEncoder?.setBuffer(sliderBuffer, offset: 0, index: 2)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
}

extension MarbleCatalog {
    func polka(context: MetalContext,
                  threshold: Float,
                  sliderValue: Float) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                    
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                    return nil
                }
                
                context.kernels.filters.polka.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: image,
                    outputTexture: outputTextureCheck,
                    threshold: threshold,
                    sliderValue: sliderValue)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
