//
//  WatermarkKernel.swift
//  Wonder
//
//  Created by PEXAVC on 8/18/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
import Metal
import MetalPerformanceShaders

public class WatermarkKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "WatermarkKernel", context: self.context)
    }
    
    public func encode(commandBuffer : MTLCommandBuffer, inputTexture : MTLTexture, watermarkTexture : MTLTexture, outputTexture : MTLTexture, offset : Float) {
        
        var offsetRef: vector_float2 = vector_float2(x: offset, y: offset)
        
        guard let kernelFunction = self.kernelFunction else { return }
        
        let (threadgroups, threadgroupCounts) = kernelFunction.threadgroupsForTexture(outputTexture)
        
        let offsetBuffer = context.device.makeBuffer(length: MemoryLayout<vector_float2>.size, options: .init(rawValue: 0))!
        memcpy(offsetBuffer.contents(), &offsetRef, offsetBuffer.length)
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(kernelFunction.pipelineState)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(watermarkTexture, index: 1)
        commandEncoder?.setTexture(outputTexture, index: 2)
        commandEncoder?.setBuffer(offsetBuffer, offset: 0, index: 0)
        commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
        commandEncoder?.endEncoding()
    }
    
}
