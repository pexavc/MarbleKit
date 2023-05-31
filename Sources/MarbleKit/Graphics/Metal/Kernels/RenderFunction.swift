//
//  RenderFunction.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
import Metal

/* Kernel function is a single function that is responsible for computing stuff on the GPU-side as a Metal kernel */
class RenderFunction {
    
    //Name of the kernel function
    let vertexName : String
    let functionName : String
    
    //Kernel associated with the function
//    private(set) lazy var kernel : MTLFunction = {
//
//        if let kernel = context.library.makeFunction(name: self.name) {
//            return kernel
//        }
//        else {
//            fatalError("Couldn't find kernel function with name \(self.name) in the default library.")
//        }
//
//    }()
    
    //Pipeline state for the function
//    private(set) lazy var pipelineState : MTLComputePipelineState = {
//
//        do {
//            let descriptor = MTLComputePipelineDescriptor()
//            descriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = false
//            descriptor.computeFunction = self.kernel
//
//            return try context.device.makeComputePipelineState(descriptor: descriptor, options: MTLPipelineOption(), reflection: nil)
//        }
//        catch let error as NSError {
//            fatalError("Couldn't initialise pipeline state for function \(self.name): \(error).")
//        }
//
//    }()
    
    private(set) lazy var vertexKernel : MTLFunction = {
        if let kernel = context.library.makeFunction(name: self.vertexName) {
            return kernel
        }
        else {
            fatalError("Could not find or create a vertex kernel.")
        }
    }()
    
    private(set) lazy var functionKernel : MTLFunction = {
        if let kernel = context.library.makeFunction(name: self.functionName) {
            return kernel
        }
        else {
            fatalError("Could not find or create a function kernel.")
        }
    }()
    
    private(set) lazy var renderPipeline : MTLRenderPipelineState = {
        
        do {
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = forcePixelFormat ?? .bgra8Unorm
            renderPipelineDescriptor.vertexFunction = self.vertexKernel
            renderPipelineDescriptor.fragmentFunction = self.functionKernel
        
            if forcePixelFormat == nil {
                forcePixelFormat = .bgra8Unorm
            }
        return try context.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        }
            catch let error as NSError {
            fatalError("Couldn't initialise pipeline state for function \(self.vertexName): \(error).")
        }
        
    }()
    
    //Setting the context
    unowned let context : MetalContext
    
    var forcePixelFormat: MTLPixelFormat?
    
    //Initialisation with a name and in the specified context
    required init(
        vertexName : String,
        functionName : String,
        context : MetalContext,
        forcePixelFormat: MTLPixelFormat? = nil) {
        
        self.vertexName = vertexName
        self.functionName = functionName
        self.context = context
        self.forcePixelFormat = forcePixelFormat
    }
    
    
}

/* Calculating the threadgroups */
//extension RenderFunction {
//    
//    func threadgroupsForTexture(_ texture : MTLTexture) -> (MTLSize, MTLSize) {
//        let w = renderPipeline.threadExecutionWidth
//        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
//        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
//        let threadgroupsPerGrid = MTLSize(
//            width: (texture.width + w - 1) / w,
//            height: (texture.height + h - 1) / h,
//            depth: 1)
//        
//        return (threadgroupsPerGrid, threadsPerThreadgroup)
//    }
//    
//}

/* Kernel functions are enumerable */
extension RenderFunction : Equatable {
    
}

func ==(lhs : RenderFunction, rhs : RenderFunction) -> Bool {
    return lhs.vertexName == rhs.vertexName
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

