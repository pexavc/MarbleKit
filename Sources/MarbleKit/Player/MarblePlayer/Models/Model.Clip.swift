//
//  Model.Clip.swift
//  MarbleKit
//
//  Created by PEXAVC on 6/25/23.
//

import AVKit
import AVFoundation
import AudioToolbox
import Foundation

class Clip {
    static var maxDuration: Double = 5
    
    static var shared: Clip = .init()
    
    static var childDebug: Bool = false
    
    //Rendering
    private var operationQueue: OperationQueue = .init()
    
    var videoFrames: [CMSampleBuffer] = []
    var audioFrames: [CMSampleBuffer] = []
    
    private var writer: AVAssetWriter? = nil
    private var audioInput: AVAssetWriterInput? = nil
    private var videoInput: AVAssetWriterInput? = nil
    private var exportURL: URL? = nil
    
    init() {
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .utility
    }
    
    func reset() {
        operationQueue.cancelAllOperations()
        self.audioFrames.removeAll()
        self.videoFrames.removeAll()
    }
}


extension Clip {
    func render(video: VideoClip, audio: AudioClip) {
        operationQueue.addOperation {
            self._render(video: video, audio: audio)
        }
        
        let debugString: String = """
        [CLIP.Render]
        fps: \(video.fps)
        sampleRate: \(audio.format?.sampleRate)
        duration: \(video.currentDuration)
        """
        print(debugString)
    }
    
    private func _render(video: VideoClip, audio: AudioClip) {
        var frameLength: Int64 = 0
        self.audioFrames = audio.getData().enumerated().compactMap {
            var time = CMTime(value: frameLength,
                              timescale: CMTimeScale(audio.format?.sampleRate ?? 48000))
            
            if let buffer = $0.element.createSampleBuffer(with: time) {
                frameLength += Int64($0.element.buffer.frameLength)
                
                return buffer
            } else {
                return nil
            }
        }
        
        self.videoFrames = video.getData().enumerated().compactMap {
            let time = CMTime(value: Int64(Float($0.offset * 600) / video.fps), timescale: CMTimeScale(600))
            
            return $0.element.createSampleBuffer(with: time, useTexture: true)
        }
        
        guard let format = audio.format,
              let buffer = video.refBuffer else {
            print("[Clip] failed to setup")
            return
        }
        
        print("[Clip] Prepared: videoFrames: \(self.videoFrames.count), audioFrames: \(self.audioFrames.count) ")
        
        #if os(macOS)
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.nameFieldLabel = "Save clip as:"
            panel.nameFieldStringValue = "clip-\(Date().timeIntervalSince1970.intValue).mp4"
            panel.canCreateDirectories = true
            panel.begin { response in
                if response == NSApplication.ModalResponse.OK,
                   let fileURL = panel.url {
                    DispatchQueue.global(qos: .background).async {
                        self.setupWriter(exportURL: fileURL,
                                         audioFormat: format,
                                         refBuffer: buffer)
                    }
                }
            }
        }
        #endif
    }
}

//MARK: -- Writing

extension Clip {
    func setupWriter(exportURL: URL, audioFormat: AVAudioFormat, refBuffer: CVPixelBuffer) {
        //guard var exportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        self.exportURL = exportURL//exportURL.appendingPathExtension("Export.mp4")
        self.writer = try? AVAssetWriter(outputURL: exportURL, fileType: AVFileType.mp4)
        
        guard self.writer != nil else { return }
        setupAudioInput(audioFormat)
        setupVideoInput(refBuffer)
        prepareWriting()
        beginWriting()
    }
    
    func setupAudioInput(_ format: AVAudioFormat) {
        let audioSampleRate = format.sampleRate
        
        let audioBitrate = Double(format.streamDescription.pointee.mBytesPerFrame) * Double(audioSampleRate)
        
        let audioBufferSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: audioBitrate,
            AVSampleRateKey: audioSampleRate,
            AVNumberOfChannelsKey: 1
        ]
        
        // Create an AVAssetWriterInput for the AVPCMBuffers
        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioBufferSettings)
        audioInput.expectsMediaDataInRealTime = false
        
        
        // Add the audio input to the asset writer
        writer?.add(audioInput)
        self.audioInput = audioInput
        
        print("[Clip] Setup Audio: \(self.audioInput != nil)")
    }
    
    func setupVideoInput(_ buffer: CVPixelBuffer) {
        let pixelBufferWidth = CVPixelBufferGetWidth(buffer)
        let pixelBufferHeight = CVPixelBufferGetHeight(buffer)
        
        
        // Create an AVAssetWriterInput for the pixelbuffers
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video,
                                            outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                                                             AVVideoWidthKey: pixelBufferWidth,
                                                            AVVideoHeightKey: pixelBufferHeight,
                                             AVVideoCompressionPropertiesKey: [
                                                AVVideoExpectedSourceFrameRateKey: 60,
                                                AVVideoAverageBitRateKey: 10485760,
                                                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                                                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                                AVVideoMaxKeyFrameIntervalKey: 60,
                                                AVVideoAllowFrameReorderingKey: 1
                                             ]])
        videoInput.expectsMediaDataInRealTime = false
        
        writer?.add(videoInput)
        self.videoInput = videoInput
        
        print("[Clip] Setup Video: \(self.videoInput != nil)")
    }
    
    func prepareWriting() {
        
        if let firstBuffer = self.videoFrames.first {
            
            writer?.startWriting()
            print("[Clip] sourceTime: \(CMSampleBufferGetPresentationTimeStamp(firstBuffer))")
            writer?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(firstBuffer))
        }
    }
    
    func beginWriting() {
        
        guard let audioInput = self.audioInput,
              let videoInput = self.videoInput else {
            print("[Clip] No inputs found")
            return
        }
        
        print("[Clip] Begin Writing")
        
        audioInput.requestMediaDataWhenReady(on: .init(label: "marble.player.clip.audio.writing", qos: .background)) {
            guard audioInput.isReadyForMoreMediaData else {
                return
            }
            
            if self.audioFrames.isEmpty {
                self.finishAudio()
                return
            } else if !audioInput.append(self.audioFrames.removeFirst()) {
                print("[Clip] Error writing audioBuffer")
            }
        }
        
        videoInput.requestMediaDataWhenReady(on: .init(label: "marble.player.clip.video.writing", qos: .background)) {
            guard videoInput.isReadyForMoreMediaData else {
                return
            }
            
            if self.videoFrames.isEmpty {
                self.finishVideo()
                return
            } else if !videoInput.append(self.videoFrames.removeFirst()) {
                print("[Clip] Error writing audioBuffer")
            }
        }
    }
    
    func finishAudio() {
        self.audioInput?.markAsFinished()
        
        print("[Clip] finish writing audio")
        
        if self.videoFrames.isEmpty {
            self.finish()
        }
    }
    
    func finishVideo() {
        self.videoInput?.markAsFinished()
        
        print("[Clip] finish writing video")
        
        if self.audioFrames.isEmpty {
            self.finish()
        }
    }
    
    func finish() {
        writer?.finishWriting {
            print("[Clip] finish writing")
            self.reset()
        }
    }
}
