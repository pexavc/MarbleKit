//
//  Model.VideoClip.swift
//  MarbleKit
//
//  Created by PEXAVC on 6/25/23.
//

import AudioToolbox
import AVKit
import Foundation

public class VideoClip: NSObject, NSCopying {
    public struct Data {
        var cmTime: CMTime
        var buffer: CVPixelBuffer
        var texture: MTLTexture
    }
    
    private var data: [Data] = []
    
    private var operationQueue: OperationQueue = .init()
    
    private var canWrite: Bool
    
    public var fps: Float = 60
    
    public var refBuffer: CVPixelBuffer?
    
    public override init() {
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .background
        canWrite = true
        super.init()
    }
    
    public init(_ data: [Data], fps: Float) {
        self.data = data
        self.fps = fps
        self.refBuffer = data.first?.buffer
        canWrite = false
        super.init()
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return VideoClip(self.data, fps: self.fps)//self.fps)
    }
    
    func update(_ cmTime: CMTime,
                fps: Float? = 60,
                buffer: CVPixelBuffer?,
                texture: MTLTexture?) {
        
        guard MarblePlayerOptions.isVideoClippingEnabled,
              canWrite else {
            if self.data.isEmpty == false {
                self.data.removeAll()
            }
            return
        }
        operationQueue.addOperation {
            guard let buffer, let texture else { return }
            self.fps = fps ?? self.fps
            
            self.data.append(.init(cmTime: cmTime, buffer: buffer, texture: texture))
            
            if Clip.childDebug {
                print("[VideoClip] Current Data: \(self.data.count)")
                print(self.description)
            }
            
            if self.currentDuration >= Clip.maxDuration {
                self.data.removeFirst()
            }
        }
    }
    
    var currentDuration: Double {
        guard let first = self.data.first else {
            return 0
        }
        
        guard let last = self.data.last else {
            return 0
        }
        
        return last.cmTime.seconds - first.cmTime.seconds
    }
    
    public override var description: String {
        return """
        [VideoClip] currentDuration: \(currentDuration)
        """
    }
    
    public func getData() -> [Data] {
        return self.data
    }
    
    public func reset() {
        self.operationQueue.cancelAllOperations()
        self.data.removeAll()
    }
}

extension VideoClip.Data {
    func createSampleBuffer(with presentationTime: CMTime,
                            useTexture: Bool = false) -> CMSampleBuffer? {
        let pixelBuffer = useTexture ? (self.texture.pixelBuffer ?? self.buffer) : self.buffer
        
        var sampleTimingInfo = CMSampleTimingInfo(duration: CMTime.invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: CMTime.invalid)
        
        var formatDescription: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        guard let description = formatDescription else {
            print("[Clip] format description error")
            return nil
        }
        
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                              imageBuffer: pixelBuffer,
                                                              formatDescription: description,
                                                              sampleTiming: &sampleTimingInfo,
                                                              sampleBufferOut: &sampleBuffer)
        
        if status != noErr {
            print("[Clip] Error creating CMSampleBuffer from pixel buffer")
            return nil
        }
        
        return sampleBuffer
    }
}
