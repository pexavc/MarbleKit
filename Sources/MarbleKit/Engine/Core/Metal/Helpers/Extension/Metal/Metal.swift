//
//  MTLDevice.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
import Metal
import CoreML

#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#endif

public extension MTLSize
{
    var hasZeroDimension: Bool {
        return depth == 0 || width == 0 || height == 0
    }
    
}

public struct ThreadgroupSizes {
    var threadsPerThreadgroup: MTLSize
    var threadgroupsPerGrid: MTLSize
    
    public static let zeros = ThreadgroupSizes(threadsPerThreadgroup: MTLSize(), threadgroupsPerGrid: MTLSize())
    
    var hasZeroDimension: Bool {
        return threadsPerThreadgroup.hasZeroDimension || threadgroupsPerGrid.hasZeroDimension
    }
    
}

public extension MTLComputePipelineState {
    /// Selects "reasonable" values for threadsPerThreadgroup and threadgroupsPerGrid for the given `drawableSize`.
    /// - Remark: The heuristics used here are not perfect. There are many ways to underutilize the GPU,
    /// including selecting suboptimal threadgroup sizes, or branching in the shader code.
    ///
    /// If you are certain you can always use threadgroups with a multiple of `threadExecutionWidth`
    /// threads, then you may want to use MTLComputePipleineDescriptor and its property
    /// `threadGroupSizeIsMultipleOfThreadExecutionWidth` to configure your pipeline state.
    ///
    /// If your shader is doing some more interesting calculations, and your threads need to share memory in some
    /// meaningful way, then you’ll probably want to do something less generalized to choose your threadgroups.
    func threadgroupSizesForDrawableSize(drawableSize: CGSize) -> ThreadgroupSizes {
        let waveSize = self.threadExecutionWidth
        let maxThreadsPerGroup = self.maxTotalThreadsPerThreadgroup
        
        let drawableWidth = Int(drawableSize.width)
        let drawableHeight = Int(drawableSize.height)
        
        if drawableWidth == 0 || drawableHeight == 0 {
            return .zeros
        }
        
        // Determine the set of possible sizes (not exceeding maxThreadsPerGroup).
        var candidates: [ThreadgroupSizes] = []
        for groupWidth in 1...maxThreadsPerGroup {
            for groupHeight in 1...(maxThreadsPerGroup/groupWidth) {
                // Round up the number of groups to ensure the entire drawable size is covered.
                // <http://stackoverflow.com/a/2745086/23649>
                let groupsPerGrid = MTLSize(width: (drawableWidth + groupWidth - 1) / groupWidth,
                                            height: (drawableHeight + groupHeight - 1) / groupHeight,
                                            depth: 1)
                
                candidates.append(ThreadgroupSizes(
                    threadsPerThreadgroup: MTLSize(width: groupWidth, height: groupHeight, depth: 1),
                    threadgroupsPerGrid: groupsPerGrid))
            }
        }
        
        /// Make a rough approximation for how much compute power will be "wasted" (e.g. when the total number
        /// of threads in a group isn’t an even multiple of `threadExecutionWidth`, or when the total number of
        /// threads being dispatched exceeds the drawable size). Smaller is better.
        func _estimatedUnderutilization(_ s: ThreadgroupSizes) -> Int {
            let excessWidth = s.threadsPerThreadgroup.width * s.threadgroupsPerGrid.width - drawableWidth
            let excessHeight = s.threadsPerThreadgroup.height * s.threadgroupsPerGrid.height - drawableHeight
            
            let totalThreadsPerGroup = s.threadsPerThreadgroup.width * s.threadsPerThreadgroup.height
            let totalGroups = s.threadgroupsPerGrid.width * s.threadgroupsPerGrid.height
            
            let excessArea = excessWidth * drawableHeight + excessHeight * drawableWidth + excessWidth * excessHeight
            let excessThreadsPerGroup = (waveSize - totalThreadsPerGroup % waveSize) % waveSize
            
            return excessArea + excessThreadsPerGroup * totalGroups
        }
        
        // Choose the threadgroup sizes which waste the least amount of execution time/power.
        let result = candidates.min { _estimatedUnderutilization($0) < _estimatedUnderutilization($1) }
        return result ?? .zeros
    }
}



/* Texture updating mechanics */
extension MTLTexture {
    public func sizeIsEqual(to size: CGSize) -> Bool {
        return self.width == Int(size.width) && self.height == Int(size.height)
    }
    
    public var size: CGSize {
        return .init(width: self.width, height: self.height)
    }
    
    var aspect: CGFloat {
        return CGFloat(min(self.width, self.height))/CGFloat(max(self.width, self.height))
    }
    
    public func update(_ buffer:[Float]){
        if pixelFormat != .r32Float {
            fatalError("Wrong pixel format while updating the texture.")
        }
        if width != buffer.count {
            fatalError("Texture size is not equal to buffer size while updating the texture.")
        }
        self.replace(region: MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: MemoryLayout<Float32>.size*buffer.count)
    }
    
    public func update(_ buffer:[UInt8]){
        if pixelFormat != .r8Uint {
            fatalError("Wrong pixel format while updating the texture.")
        }
        if width != buffer.count {
            fatalError("Texture size is not equal to buffer size while updating the texture.")
        }
        self.replace(region: MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: MemoryLayout<UInt8>.size*buffer.count)
    }
    
    public func update(_ buffer:[[UInt8]]){
        if pixelFormat != .r8Unorm {
            fatalError("Wrong pixel format while updating the texture.")
        }
        if width != buffer[0].count {
            fatalError("Texture size is not equal to buffer size while updating the texture.")
        }
        if height != buffer.count {
            fatalError("Texture size is not equal to buffer size while updating the texture.")
        }
        for i in 0 ..< height {
            self.replace(region: MTLRegionMake2D(0, i, width, 1), mipmapLevel: 0, withBytes: buffer[i], bytesPerRow: width)
        }
    }
    
    public func update(_ buffers:[[Float]]){
        if pixelFormat != .r32Float {
            fatalError("Wrong pixel format while updating the texture.")
        }
        
        let region = MTLRegionMake2D(0, 0, width, 1)
        let bytesPerRow = region.size.width * MemoryLayout<Float32>.size
        
        for index in 0 ..< buffers.count {
            let curve = buffers[index]
            if width != curve.count {
                fatalError("Texture size is not equal to buffer size while updating the texture.")
            }
            self.replace(region: region, mipmapLevel:0, slice:index, withBytes:curve, bytesPerRow:bytesPerRow, bytesPerImage:0)
        }
    }
}

/* Texture generation extension */
extension MTLDevice {
    public func fromMM(_ mm: MLMultiArray) -> MTLTexture {
        let length = mm.count
        let floatPtr =  mm.dataPointer.bindMemory(to: Float.self, capacity: length)
        let floatBuffer = UnsafeBufferPointer(start: floatPtr, count: length)
        let floatArray = Array(floatBuffer)
        
        var bytePerRow = 4
        
        var height: Int = (mm.shape[1] as? Int ?? 0)
        var width: Int = (mm.shape[2] as? Int ?? 0)
        
        var finalFloatArray: [[Float]] = .init(repeating: .init(repeating: 0, count: width), count: height)
        
        for y in 0..<height {
            for x in 0..<width {
                finalFloatArray[y][x] = floatArray[(y*width + x)]
                
            }
        }
        
        return texture2D(finalFloatArray, width: width, height: height)
    }
    
    //Generating 1D texture from float array
    public func texture1D(_ buffer : [Float]) -> MTLTexture {
        
        let weightsTextureDescriptor = MTLTextureDescriptor()
        weightsTextureDescriptor.textureType = .type1D
        weightsTextureDescriptor.pixelFormat = .r32Float
        weightsTextureDescriptor.width = buffer.count
        weightsTextureDescriptor.height = 1
        weightsTextureDescriptor.depth = 1
        
        let texture = self.makeTexture(descriptor: weightsTextureDescriptor)
        texture?.update(buffer)
        return texture!
        
    }
    
    public func texture2D(_ buffer : [[Float]], width: Int, height: Int) -> MTLTexture {
        
        let weightsTextureDescriptor = MTLTextureDescriptor()
        weightsTextureDescriptor.textureType = .type2D
        weightsTextureDescriptor.pixelFormat = .r32Float
        weightsTextureDescriptor.width = width
        weightsTextureDescriptor.height = height
        weightsTextureDescriptor.depth = 1
        
        let texture = self.makeTexture(descriptor: weightsTextureDescriptor)
        let region = MTLRegionMake2D(0, 0, weightsTextureDescriptor.width, weightsTextureDescriptor.height)
        let bytesPerRow = region.size.width * region.size.height * MemoryLayout<Float32>.size
        
        for i in 0 ..< region.size.height {
            texture?.replace(
                region: MTLRegionMake2D(0, i, region.size.width, 1),
                mipmapLevel: 0, withBytes: buffer[i],
                bytesPerRow: region.size.width * bytesPerRow)
        }
        return texture!
        
    }
    
    public func texture1D(_ buffer:[UInt8]) -> MTLTexture {
        
        let weightsTextureDescriptor = MTLTextureDescriptor()
        weightsTextureDescriptor.textureType = .type1D
        weightsTextureDescriptor.pixelFormat = .r8Uint
        weightsTextureDescriptor.width = buffer.count
        weightsTextureDescriptor.height = 1
        weightsTextureDescriptor.depth  = 1
        
        let texture = self.makeTexture(descriptor: weightsTextureDescriptor)
        texture?.update(buffer)
        return texture!
        
    }
    
    public func texture2D(_ buffer:[[UInt8]]) -> MTLTexture {
        
        let width = buffer[0].count
        let weightsDescription = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: buffer.count, mipmapped: false)
        let texture = self.makeTexture(descriptor: weightsDescription)
        texture?.update(buffer)
        return texture!
        
    }
    
    public func texture1DArray(_ buffers:[[Float]]) -> MTLTexture {
        
        let width = buffers[0].count
        
        for i in 1 ..< buffers.count {
            if (width != buffers[i].count) {
                fatalError("texture buffers must have identical size...")
            }
        }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type1DArray
        textureDescriptor.width  = width
        textureDescriptor.height = 1
        textureDescriptor.depth = 1
        textureDescriptor.pixelFormat = .r32Float
        textureDescriptor.arrayLength = buffers.count
        textureDescriptor.mipmapLevelCount = 1
        
        let texture = self.makeTexture(descriptor: textureDescriptor)
        texture?.update(buffers)
        return texture!
        
    }
    
    public func makeTextureSimilarTo(_ texture : MTLTexture) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return self.makeTexture(descriptor: textureDescriptor)
    }
    
}

extension MTLComputeCommandEncoder {
    /**
     Dispatches a compute kernel on a 1-dimensional grid.
     
     - Parameters:
     - count: the number of elements to process
     */
    public func dispatch(pipeline: MTLComputePipelineState, count: Int) {
        // Round off count to the nearest multiple of threadExecutionWidth.
        let width = pipeline.threadExecutionWidth
        let rounded = ((count + width - 1) / width) * width
        
        let blockSize = min(rounded, pipeline.maxTotalThreadsPerThreadgroup)
        let numBlocks = (count + blockSize - 1) / blockSize
        
        let threadGroupSize = MTLSizeMake(blockSize, 1, 1)
        let threadGroups = MTLSizeMake(numBlocks, 1, 1)
        
        setComputePipelineState(pipeline)
        dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }
    
    /**
     Dispatches a compute kernel on a 2-dimensional grid.
     
     - Parameters:
     - width: the first dimension
     - height: the second dimension
     */
    public func dispatch(pipeline: MTLComputePipelineState, width: Int, height: Int) {
        let w = pipeline.threadExecutionWidth
        let h = pipeline.maxTotalThreadsPerThreadgroup / w
        
        let threadGroupSize = MTLSizeMake(w, h, 1)
        
        let threadGroups = MTLSizeMake(
            (width  + threadGroupSize.width  - 1) / threadGroupSize.width,
            (height + threadGroupSize.height - 1) / threadGroupSize.height, 1)
        
        setComputePipelineState(pipeline)
        dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }
    
    /**
     Dispatches a compute kernel on a 3-dimensional image grid.
     
     - Parameters:
     - width: the width of the image in pixels
     - height: the height of the image in pixels
     - featureChannels: the number of channels in the image
     - numberOfImages: the number of images in the batch (default is 1)
     */
    public func dispatch(pipeline: MTLComputePipelineState,
                         width: Int,
                         height: Int,
                         featureChannels: Int,
                         numberOfImages: Int = 1) {
        let slices = ((featureChannels + 3)/4) * numberOfImages
        
        let w = pipeline.threadExecutionWidth
        let h = pipeline.maxTotalThreadsPerThreadgroup / w
        let d = 1
        let threadGroupSize = MTLSizeMake(w, h, d)
        
        let threadGroups = MTLSizeMake(
            (width  + threadGroupSize.width  - 1) / threadGroupSize.width,
            (height + threadGroupSize.height - 1) / threadGroupSize.height,
            (slices + threadGroupSize.depth  - 1) / threadGroupSize.depth)
        
        //printGrid(threadgroups: threadGroups, threadsPerThreadgroup: threadGroupSize)
        
        setComputePipelineState(pipeline)
        dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }
    
    /**
     For debugging the threadgroup sizes.
     */
    public func printGrid(threadGroups: MTLSize, threadsPerThreadgroup: MTLSize) {
        let groups = threadGroups
        let threads = threadsPerThreadgroup
        let grid = MTLSizeMake(groups.width  * threads.width,
                               groups.height * threads.height,
                               groups.depth  * threads.depth)
        
        print("threadGroups: \(groups.width)x\(groups.height)x\(groups.depth)"
            + ", threadsPerThreadgroup: \(threads.width)x\(threads.height)x\(threads.depth)"
            + ", grid: \(grid.width)x\(grid.height)x\(grid.depth)")
    }
    
}


