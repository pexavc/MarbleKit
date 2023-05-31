//
//  BackdropKernel.swift
//  Wonder
//
//  Created by PEXAVC on 8/17/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Metal
import MetalPerformanceShaders

class BackdropKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "BackdropKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer,
                inputTexture : MTLTexture,
                backdropTexture : MTLTexture,
                outputTexture : MTLTexture,
                opacity: Float = 1.0) {
        
        var opacityRef: Float = opacity
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        guard let opacityBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: .init(rawValue: 0)) else {
            return
        }
        memcpy(opacityBuffer.contents(), &opacityRef, opacityBuffer.length)
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(backdropTexture, index: 1)
        commandEncoder?.setTexture(outputTexture, index: 2)
        commandEncoder?.setBuffer(opacityBuffer, offset: 0, index: 0)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}

extension MarbleCatalog {
    func backdrop(context: MetalContext,
                  backdropTexture: MTLTexture,
                  opacity: Float) -> MetalFilter {
        return { image in
            autoreleasepool {
                guard let image = image else { return nil }
                let outputTexture = context.device.makeTextureSimilarTo(image)
                
                guard let commandBuffer = context.commandQueue.makeCommandBuffer(), let outputTextureCheck = outputTexture else {
                    return nil
                }
                
                context.kernels.filters.backdrop.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: image,
                    backdropTexture: backdropTexture,
                    outputTexture: outputTextureCheck,
                    opacity: opacity)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                return outputTextureCheck
            }
        }
    }
}
