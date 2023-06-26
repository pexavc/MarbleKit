//
//  AudioOutput.swift
//  MarbleKit.Player
//
//  Based on:  https://github.com/kingslay/KSPlayer/blob/develop/Sources/KSPlayer/MEPlayer/AudioEnginePlayer.swift
//  Created by kintan on 2018/3/11.
//

import AVFoundation
import CoreAudio

protocol AudioPlayer: AnyObject {
    var playbackRate: Float { get set }
    var volume: Float { get set }
    var isMuted: Bool { get set }
    var attackTime: Float { get set }
    var releaseTime: Float { get set }
    var threshold: Float { get set }
    var expansionRatio: Float { get set }
    var overallGain: Float { get set }
    func prepare(audioFormat: AVAudioFormat)
    func play(time: TimeInterval)
    func pause()
    func flush()
}

final class AudioEnginePlayer: AudioPlayer, MarblePlayerFrameOutput {
    public var attackTime: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var releaseTime: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var threshold: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var expansionRatio: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    public var overallGain: Float {
        get {
            var value = AudioUnitParameterValue(1.0)
            AudioUnitGetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, &value)
            return value
        }
        set {
            AudioUnitSetParameter(dynamicsProcessor.audioUnit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, AudioUnitParameterValue(newValue), 0)
        }
    }

    private let engine = AVAudioEngine()

    private let timePitch = AVAudioUnitTimePitch()
    private let dynamicsProcessor = AVAudioUnitEffect(audioComponentDescription:
        AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                  componentSubType: kAudioUnitSubType_DynamicsProcessor,
                                  componentManufacturer: kAudioUnitManufacturer_Apple,
                                  componentFlags: 0,
                                  componentFlagsMask: 0))
    private var currentRenderReadOffset = UInt32(0)
    private var sampleSize = UInt32(MemoryLayout<Float>.size)
    weak var renderSource: MarblePlayerRenderSourceDelegate?
    private var currentRender: AudioFrame? {
        didSet {
            if currentRender == nil {
                currentRenderReadOffset = 0
            }
        }
    }

    var isPaused: Bool {
        engine.isRunning
    }

    var playbackRate: Float {
        get {
            timePitch.rate
        }
        set {
            timePitch.rate = min(32, max(1 / 32, newValue))
        }
    }

    var volume: Float {
        get {
            engine.mainMixerNode.volume
        }
        set {
            engine.mainMixerNode.volume = newValue
        }
    }

    public var isMuted: Bool {
        get {
            engine.mainMixerNode.outputVolume == 0.0
        }
        set {
            engine.mainMixerNode.outputVolume = newValue ? 0.0 : 1.0
        }
    }

    func prepare(audioFormat: AVAudioFormat) {
        engine.stop()
        engine.reset()
        sampleSize = audioFormat.sampleSize
        MarblePlayerLog("outputFormat channelLayout AudioFormat: \(audioFormat)")
        if let channelLayout = audioFormat.channelLayout {
            MarblePlayerLog("outputFormat channelLayout tag: \(channelLayout.layoutTag)")
            MarblePlayerLog("outputFormat channelLayout channelDescriptions: \(channelLayout.layout.channelDescriptions)")
        }
        //        engine.attach(nbandEQ)
        //        engine.attach(distortion)
        //        engine.attach(delay)
        let sourceNode = AVAudioSourceNode(format: audioFormat) { [weak self] _, _, frameCount, audioBufferList in
            self?.audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer(audioBufferList), numberOfFrames: frameCount)
            return noErr
        }
        engine.attach(sourceNode)
        engine.attach(dynamicsProcessor)
        engine.attach(timePitch)
        engine.connect(nodes: [sourceNode, dynamicsProcessor, timePitch, engine.mainMixerNode], format: audioFormat)
        if let audioUnit = engine.outputNode.audioUnit {
            addRenderNotify(audioUnit: audioUnit)
        }
        engine.prepare()
    }

    func play(time _: TimeInterval) {
        if !engine.isRunning {
            try? engine.start()
        }
    }

    func pause() {
        engine.pause()
    }

    func flush() {
        currentRender = nil
    }

    private func addRenderNotify(audioUnit: AudioUnit) {
        AudioUnitAddRenderNotify(audioUnit, { refCon, ioActionFlags, inTimeStamp, _, _, ioData in
            let `self` = Unmanaged<AudioEnginePlayer>.fromOpaque(refCon).takeUnretainedValue()
            autoreleasepool {
                if ioActionFlags.pointee.contains(.unitRenderAction_PostRender) {
                    self.audioPlayerDidRenderSample(sampleTimestamp: inTimeStamp.pointee, ioData: ioData?.pointee)
                    
                }
            }
            return noErr
        }, Unmanaged.passUnretained(self).toOpaque())
    }
    
    private func audioPlayerShouldInputData(ioData: UnsafeMutableAudioBufferListPointer, numberOfFrames: UInt32) {
        var ioDataWriteOffset = 0
        var numberOfSamples = numberOfFrames
        while numberOfSamples > 0 {
            if currentRender == nil {
                currentRender = renderSource?.getAudioOutputRender()
                
                if let currentRender {
                    
                    let currentPreparePosition = currentRender.position + currentRender.duration * Int64(self.currentRenderReadOffset) / Int64(currentRender.numberOfSamples)
                    renderSource?.setAudio(time: currentRender.timebase.cmtime(for: currentPreparePosition), frame: currentRender)
                }
            }
            guard let currentRender else {
                break
            }
            let residueLinesize = currentRender.numberOfSamples - currentRenderReadOffset
            guard residueLinesize > 0 else {
                self.currentRender = nil
                continue
            }
            let framesToCopy = min(numberOfSamples, residueLinesize)
            let bytesToCopy = Int(framesToCopy * sampleSize)
            let offset = Int(currentRenderReadOffset * sampleSize)
            for i in 0 ..< min(ioData.count, currentRender.data.count) {
                (ioData[i].mData! + ioDataWriteOffset).copyMemory(from: currentRender.data[i]! + offset, byteCount: bytesToCopy)
            }
            
            numberOfSamples -= framesToCopy
            ioDataWriteOffset += bytesToCopy
            currentRenderReadOffset += framesToCopy
        }
        let sizeCopied = (numberOfFrames - numberOfSamples) * sampleSize
        for i in 0 ..< ioData.count {
            let sizeLeft = Int(ioData[i].mDataByteSize - sizeCopied)
            if sizeLeft > 0 {
                memset(ioData[i].mData! + Int(sizeCopied), 0, sizeLeft)
            }
        }
    }

    private func audioPlayerDidRenderSample(sampleTimestamp _: AudioTimeStamp, ioData: AudioBufferList?) {
        if let currentRender {
            let currentPreparePosition = currentRender.position + currentRender.duration * Int64(currentRenderReadOffset) / Int64(currentRender.numberOfSamples)
            if currentPreparePosition > 0 {
                renderSource?.setAudio(time: currentRender.timebase.cmtime(for: currentPreparePosition))
            }
        }
    }
}

extension AVAudioEngine {
    func connect(nodes: [AVAudioNode], format: AVAudioFormat?) {
        if nodes.count < 2 {
            return
        }
        for i in 0 ..< nodes.count - 1 {
            connect(nodes[i], to: nodes[i + 1], format: format)
        }
    }
}
