//
//  AnalogKernel.swift
//  Wonder
//
//  Created by 0xKala on 1/10/20.
//  Copyright © 2020 0xKala. All rights reserved.
//
import Metal
import MetalPerformanceShaders

class AnalogKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "AnalogKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer, inputTexture : MTLTexture, outputTexture : MTLTexture, type : Int, threshold : Float) {
        
        var thresholdRef: Float = threshold
        var typeRef: Float = Float(type)
        
        var timeRef: Float = (Float(DispatchTime.now().uptimeNanoseconds) / 1000000000.0)
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        
        guard let thresholdBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(thresholdBuffer.contents(), &thresholdRef, thresholdBuffer.length)
        
        guard let typeBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(typeBuffer.contents(), &typeRef, typeBuffer.length)
        
        guard let timeBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(timeBuffer.contents(), &timeRef, timeBuffer.length)
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(outputTexture, index: 1)
        commandEncoder?.setBuffer(thresholdBuffer, offset: 0, index: 0)
        commandEncoder?.setBuffer(typeBuffer, offset: 0, index: 1)
        commandEncoder?.setBuffer(timeBuffer, offset: 0, index: 2)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}

extension MarbleCatalog {
    func analog(context: MetalContext, type: Int, threshold: Float) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                    return nil
                }
                
                context.kernels.filters.analog.encode(commandBuffer: commandBuffer, inputTexture: image, outputTexture: outputTextureCheck, type: type, threshold: threshold)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
