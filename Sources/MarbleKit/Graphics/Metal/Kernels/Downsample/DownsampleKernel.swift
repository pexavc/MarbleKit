import Metal
import MetalPerformanceShaders

class DownsampleKernel {

    fileprivate unowned let context : MetalContext
    fileprivate var kernelFunction : KernelFunction?

    init(context : MetalContext) {
        self.context = context

        if
            #available(iOSApplicationExtension 11.0, *),
            MPSSupportsMTLDevice(context.device)
        {
            //Nothing to do here
        } else {
            self.kernelFunction = KernelFunction(name: "PODownsample", context: self.context)
        }
    }

    func encode(commandBuffer : MTLCommandBuffer, inputTexture : MTLTexture, outputTexture : MTLTexture) {
        
        if #available(iOSApplicationExtension 11.0, *),
            MPSSupportsMTLDevice(context.device)
        {
            let mpsKernelFunction = MPSImageBilinearScale(device: self.context.device)
            
            let scaleX = Double(outputTexture.width) / Double(inputTexture.width)
            let scaleY = Double(outputTexture.height) / Double(inputTexture.height)
            
            let offsetX = 0.0//Double(inputTexture.width - outputTexture.width) * 0.5
            let offsetY = 0.0//Double(inputTexture.height - outputTexture.height) * 0.5
//            print("""
//                outputTexture.width: \(outputTexture.width), outputTexture.height: \(outputTexture.height)
//                inputTexture.width: \(inputTexture.width), inputTexture.height: \(inputTexture.height)
//                offsetX: \(offsetX), offsetY: \(offsetY)
//                scaleX: \(scaleX), scaleY: \(scaleY)
//                """)
            
            var transform = MPSScaleTransform(scaleX: scaleX, scaleY: scaleY, translateX: offsetX, translateY: offsetY)

            withUnsafePointer(to: &transform) { ptr in
                mpsKernelFunction.scaleTransform = ptr
            }

            mpsKernelFunction.encode(commandBuffer: commandBuffer,
                                     sourceTexture: inputTexture,
                                     destinationTexture: outputTexture)
        }
        else {
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

}
