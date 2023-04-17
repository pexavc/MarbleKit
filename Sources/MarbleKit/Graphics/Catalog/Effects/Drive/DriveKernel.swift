//
//  GlitchKernel.swift
//  Wonder
//
//  Created by 0xKala on 8/14/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Foundation
import Metal
import MetalPerformanceShaders

class DriveKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "DriveKernel", context: self.context)
    }
    
    func encode(
        commandBuffer : MTLCommandBuffer,
        inputTexture : MTLTexture,
        outputTexture : MTLTexture,
        threshold : Float,
        sliderValue: Float) {
        
        /**
         
         uptimeNanoSeconds is used as a time reference to correctly animate the GlitchKernel
         But we are using the threshold from the sound's max sample instead here.
         
         */
        var timeRef: Float = (Float(DispatchTime.now().uptimeNanoseconds) / 1000000000.0)//threshold
        var thresholdRef: Float = threshold
        var sliderRef: Float = sliderValue
        
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
        
        guard let sliderBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        
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
    func drive(context: MetalContext, threshold: Float, sliderValue: Float) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                    return nil
                }
                
                context.kernels.filters.drive.encode(commandBuffer: commandBuffer, inputTexture: image, outputTexture: outputTextureCheck, threshold: threshold, sliderValue: sliderValue)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
