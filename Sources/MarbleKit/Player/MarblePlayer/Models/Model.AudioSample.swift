//
//  Model.AudioSample.swift
//  MarbleKit
//
//  Created by PEXAVC on 6/23/23.
//

import AudioToolbox
import Foundation
import AVFAudio
import Accelerate

public final class AudioSample: NSObject, ObservableObject {
    public static var isEnabled: Bool = true
    
    public static var shared: AudioSample = .init()
    
    public struct Stats {
        var amplitude: Float = 0
        var dB: Float = 0
        
        public var disply_dB: Float {
            60 - abs(dB)
        }
    }
    
    @Published public var stats: Stats = .init()
    
    public var isReady: Bool {
        AudioSample.isEnabled
    }
    
    public var sampleRate: Double {
        MarblePlayerOptions.sampleRate
    }
    
    var debug: Bool = true
    
    var bufferSize: Int
    
    var amplitude: Float = 0
    var dB: Float = 0
    
    let maxSampleValue: Float = 32767 //16-bit max
    
    var lastBuffer: AVAudioPCMBuffer? = nil
    
    init(_ bufferSize: Int = .max) {
        self.bufferSize = 8
        super.init()
    }
    
    func load(_ bufferSize: Int = .max) {
        self.bufferSize = Int(sqrt(Float(bufferSize)))
    }
    
    func update(_ buffer: AVAudioPCMBuffer?) {
        guard AudioSample.isEnabled, let buffer = buffer else { return }
        
        self.lastBuffer = buffer
        
        let level = calculateDB(from: buffer)
        self.amplitude = level.amplitude * 5
        self.dB = level.dB
        
        DispatchQueue.main.async {
            if self.amplitude.isFinite && self.dB.isFinite {
                self.stats = Stats(amplitude: self.amplitude, dB: self.dB)
            }
        }
    }

    func calculateDB(from buffer: AVAudioPCMBuffer) -> (amplitude: Float, dB: Float) {
        guard let channelData = buffer.floatChannelData else {
            return (0.0, 0.0)
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        var squares = [Float](repeating: 0, count: frameLength)

        vDSP_vsq(channelData[0], 1, &squares, 1, UInt(frameLength))

        for i in 1..<channelCount {
            var channelSquares = [Float](repeating: 0, count: frameLength)
            vDSP_vsq(channelData[i], 1, &channelSquares, 1, UInt(frameLength))
            vDSP_vadd(squares, 1, channelSquares, 1, &squares, 1, UInt(frameLength))
        }

        var mean: Float = 0
        vDSP_meanv(squares, 1, &mean, UInt(squares.count))

        let rootMeanSquare = sqrt(mean)
        let amplitude = rootMeanSquare * sqrt(2.0)
        
        let dB = 20.0 * log10(amplitude)

        return (amplitude, dB)
    }

    public override var description: String {
        """
        [AudioSample]
        amplitude: \(amplitude)
        dB: \(dB)
        """
    }
    
    func log() {
        guard AudioSample.isEnabled && debug else { return }
        print(description)
    }
}
