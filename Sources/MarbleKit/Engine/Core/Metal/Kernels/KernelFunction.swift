//
//  KernelFunction.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
import Metal

/* Kernel function is a single function that is responsible for computing stuff on the GPU-side as a Metal kernel */
class KernelFunction {
    
    //Name of the kernel function
    let name : String
    
    //Kernel associated with the function
    private(set) lazy var kernel : MTLFunction = {
        
        if let kernel = context.library.makeFunction(name: self.name) {
            return kernel
        }
        else {
            fatalError("Couldn't find kernel function with name \(self.name) in the default library.")
        }
        
    }()
    
    //Pipeline state for the function
    private(set) lazy var pipelineState : MTLComputePipelineState = {
        
        do {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = false
            descriptor.computeFunction = self.kernel
            
            return try context.device.makeComputePipelineState(descriptor: descriptor, options: MTLPipelineOption(), reflection: nil)
        }
        catch let error as NSError {
            fatalError("Couldn't initialise pipeline state for function \(self.name): \(error).")
        }
        
    }()
    
    //Setting the context
    unowned let context : MetalContext
    
    //Initialisation with a name and in the specified context
    required init(name : String, context : MetalContext) {
        self.name = name
        self.context = context
    }
    
    
}

/* Calculating the threadgroups */
extension KernelFunction {
    
    func threadgroupsForTexture(_ texture : MTLTexture) -> (MTLSize, MTLSize) {
        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadgroupsPerGrid = MTLSize(
            width: (texture.width + w - 1) / w,
            height: (texture.height + h - 1) / h,
            depth: 1)
        
        return (threadgroupsPerGrid, threadsPerThreadgroup)
    }
    
}

/* Kernel functions are enumerable */
extension KernelFunction : Equatable {
    
}

func ==(lhs : KernelFunction, rhs : KernelFunction) -> Bool {
    return lhs.name == rhs.name
}

//Integer extension
fileprivate extension Int {
    
    func greatestDivisor(below: Int) -> Int? {
        // Could use improvement
        var i = below
        while (self % i != 0 && i > 1) { i -= 1 }
        if i <= 1 { return nil }
        return i
        
    }
    
}

