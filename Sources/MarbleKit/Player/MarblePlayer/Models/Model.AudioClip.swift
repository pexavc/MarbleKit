//
//  Model.AudioClip.swift
//  MarbleKit
//
//  Created by PEXAVC on 6/25/23.
//

import AudioToolbox
import AVKit
import Foundation

public class AudioClip: NSObject, NSCopying {
    
    public struct Data {
        var cmTime: CMTime
        var buffer: AVAudioPCMBuffer
        var format: AVAudioFormat
        var frameCount: Int
    }
    
    private var data: [Data] = []
    
    private var operationQueue: OperationQueue = .init()
    
    private var canWrite: Bool
    
    public var format: AVAudioFormat? = nil
    
    public override init() {
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .background
        canWrite = true
        super.init()
    }
    
    public init(_ data: [Data]) {
        self.data = data
        self.format = data.first?.format
        canWrite = false
        super.init()
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return AudioClip(self.data)
    }
    
    func update(_ cmTime: CMTime, buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        guard MarblePlayerOptions.isVideoClippingEnabled,
              canWrite else {
            if self.data.isEmpty == false {
                self.data.removeAll()
            }
            return
        }
        operationQueue.addOperation {
            
            self.data.append(.init(cmTime: cmTime,
                                   buffer: buffer,
                                   format: format,
                                   frameCount: Int(ceil(format.sampleRate * self.getDurationLast(cmTime).seconds))))
            
            if Clip.childDebug {
                print("[AudioClip] Current Data: \(self.data.count)")
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
    
    func getDurationLast(_ cmTime: CMTime) -> CMTime {
        guard let last = self.data.last else {
            return .zero
        }
        
        return .init(seconds: cmTime.seconds - last.cmTime.seconds)
    }
    
    func getPresentationTime(_ data: Data) -> CMTime {
        var frames: Int = 0
        
        for dataItem in self.data {
            if dataItem.cmTime == data.cmTime {
                break
            }
            
            frames += data.frameCount
        }
        
        return .init(value: CMTimeValue(frames),
                     timescale: CMTimeScale(data.format.sampleRate))
    }
    
    public override var description: String {
        return """
        [AudioClip] currentDuration: \(currentDuration)
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

extension AudioClip.Data {
    func createSampleBuffer(with presentationTime: CMTime) -> CMSampleBuffer? {
        let pcmBuffer = self.buffer
        let audioBufferList = pcmBuffer.mutableAudioBufferList
        
        let asbd = pcmBuffer.format.streamDescription
        
        var sampleBuffer: CMSampleBuffer? = nil
        var format: CMFormatDescription? = nil
        
        var status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                    asbd: asbd,
                                                    layoutSize: 0,
                                                    layout: nil,
                                                    magicCookieSize: 0,
                                                    magicCookie: nil,
                                                    extensions: nil,
                                                    formatDescriptionOut: &format);
        if (status != noErr) { return nil }
        
        let numSamples = pcmBuffer.frameLength
        let sampleRate = asbd.pointee.mSampleRate
        
        var timing: CMSampleTimingInfo = CMSampleTimingInfo(duration: CMTime(value: 1,
                                                                             timescale: Int32(asbd.pointee.mSampleRate)),
                                                            presentationTimeStamp: presentationTime,
                                                            decodeTimeStamp: CMTime.invalid)
        
        print("[Clip] Processing Audio (\(presentationTime.seconds)): \(audioBufferList.pointee.mNumberBuffers) buffers")
        
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: nil,
                                      dataReady: false,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: format,
                                      sampleCount: Int(numSamples),
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &timing,
                                      sampleSizeEntryCount: 0,
                                      sampleSizeArray: [Int(pcmBuffer.frameLength)],
                                      sampleBufferOut: &sampleBuffer);
        
        if (status != noErr) { NSLog("[Clip] CMSampleBufferCreate returned error: \(status)"); return nil }
        
        status = CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer!,
                                                                blockBufferAllocator: kCFAllocatorDefault,
                                                                blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                                flags: 0,
                                                                bufferList: &audioBufferList.pointee);
        if (status != noErr) { NSLog("[Clip] CMSampleBufferSetDataBufferFromAudioBufferList returned error: \(status)"); return nil; }
        
        return sampleBuffer
    }
}
