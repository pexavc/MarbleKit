//
//  PaddedDownsample.swift
//  Marble
//
//  Created by 0xKala on 8/10/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

import Foundation
import Metal
import MetalPerformanceShaders

class PaddedDownsampleKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "PaddedDownsampleKernel", context: self.context)
    }
    
    func encode(
        commandBuffer : MTLCommandBuffer,
        inputTexture : MTLTexture,
        outputTexture : MTLTexture) {
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(outputTexture, index: 1)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}



