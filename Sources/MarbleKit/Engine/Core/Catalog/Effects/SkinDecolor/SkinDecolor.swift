//
//  SkinDecolor.swift
//  Wonder
//
//  Created by PEXAVC on 8/17/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Metal
import MetalPerformanceShaders

class SkinDecolorKernel {
    
    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?
    
    init(context : MetalContext) {
        self.context = context
        
        self.kernelFunction = KernelFunction(name: "SkinDecolorKernel", context: self.context)
    }
    
    func encode(commandBuffer : MTLCommandBuffer,
                inputTexture : MTLTexture,
                outputTexture : MTLTexture,
                threshold : Float) {
        
        var thresholdRef: Float = /*(Float(DispatchTime.now().uptimeNanoseconds) / 200000000.0) */ threshold
        
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
