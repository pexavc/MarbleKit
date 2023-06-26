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
        public var fft: [Float] = []
        
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
    
    var operationQueueFFT: OperationQueue = .init()
    
    private let  queue: DispatchQueue = .init(label: "marblekit.audio.analysis", qos: .userInteractive)
    
    init(_ bufferSize: Int = .max) {
        self.bufferSize = 8
        super.init()
        self.operationQueueFFT.underlyingQueue = queue
        self.operationQueueFFT.maxConcurrentOperationCount = 1
    }
    
    func load(_ bufferSize: Int = .max) {
        self.bufferSize = Int(sqrt(Float(bufferSize)))
    }
    
    func update(_ buffer: AVAudioPCMBuffer?) {
        guard AudioSample.isEnabled, let buffer = buffer else { return }
        
        self.lastBuffer = buffer
        
        operationQueueFFT.addOperation {
            let level = self.calculateDB(from: buffer)
            self.amplitude = level.amplitude * 5
            self.dB = level.dB
            
            let fft = self.performFFT(buffer: buffer)
            
            DispatchQueue.main.async {
                if self.amplitude.isFinite && self.dB.isFinite {
                    self.stats = Stats(amplitude: self.amplitude, dB: self.dB, fft: fft)
                }
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
    
    //Based on: https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/Taps/FFTTap.swift
    func performFFT(buffer: AVAudioPCMBuffer,
                    isNormalized: Bool = true,
                    zeroPaddingFactor: UInt32 = 0) -> [Float] {
        let frameCount = buffer.frameLength + buffer.frameLength * zeroPaddingFactor
        
//        let preferredBinCount: Double = 16
//        let preferredLog2n = UInt(log2(preferredBinCount))
        let log2n = UInt(round(log2(Double(frameCount))))//UInt(preferredLog2n + 1)
        let bufferSizePOT = Int(1 << log2n) // 1 << n = 2^n
        let binCount = bufferSizePOT / 2

        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        
        var output = DSPSplitComplex(repeating: 0, count: binCount)
        defer {
            output.deallocate()
        }

        let windowSize = Int(buffer.frameLength)
        var transferBuffer = [Float](repeating: 0, count: bufferSizePOT)
        var window = [Float](repeating: 0, count: windowSize)

        // Hann windowing to reduce the frequency leakage
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul((buffer.floatChannelData?.pointee)!, 1, window,
                  1, &transferBuffer, 1, vDSP_Length(windowSize))

        // Transforming the [Float] buffer into a UnsafePointer<Float> object for the vDSP_ctoz method
        // And then pack the input into the complex buffer (output)
        transferBuffer.withUnsafeBufferPointer { pointer in
            pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self,
                                                   capacity: transferBuffer.count) {
                vDSP_ctoz($0, 2, &output, 1, vDSP_Length(binCount))
            }
        }

        // Perform the FFT
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, FFTDirection(FFT_FORWARD))

        let scaledBinCount = 16
        
        // Parseval's theorem - Scale with respect to the number of bins
        var scaledOutput = DSPSplitComplex(repeating: 0, count: scaledBinCount)
        var scaleMultiplier = DSPSplitComplex(repeatingReal: 1.0 / Float(scaledBinCount), repeatingImag: 0, count: 1)
        defer {
            scaledOutput.deallocate()
            scaleMultiplier.deallocate()
        }
        
        vDSP_zvzsml(&output,
                    1,
                    &scaleMultiplier,
                    &scaledOutput,
                    1,
                    vDSP_Length(scaledBinCount))

        var magnitudes = [Float](repeating: 0.0, count: scaledBinCount)
        vDSP_zvmags(&scaledOutput, 1, &magnitudes, 1, vDSP_Length(scaledBinCount))
        vDSP_destroy_fftsetup(fftSetup)

        if !isNormalized {
            return magnitudes
        }

        // normalize according to the momentary maximum value of the fft output bins
        var normalizationMultiplier: [Float] = [1.0 / (magnitudes.max() ?? 1.0)]
        var normalizedMagnitudes = [Float](repeating: 0.0, count: scaledBinCount)
        vDSP_vsmul(&magnitudes,
                   1,
                   &normalizationMultiplier,
                   &normalizedMagnitudes,
                   1,
                   vDSP_Length(scaledBinCount))
        return normalizedMagnitudes
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

//Based on: https://github.com/AudioKit/AudioKit/blob/618df54cf5a31ae267d3957cf8a2f03a137f16cf/Sources/AudioKit/Internals/Utilities/AudioKitHelpers.swift#L376
public extension DSPSplitComplex {
    /// Initialize a DSPSplitComplex with repeating values for real and imaginary splits
    ///
    /// - Parameters:
    ///   - initialValue: value to set elements to
    ///   - count: number of real and number of imaginary elements
    init(repeating initialValue: Float, count: Int) {
        let real = [Float](repeating: initialValue, count: count)
        let realp = UnsafeMutablePointer<Float>.allocate(capacity: real.count)
        realp.assign(from: real, count: real.count)

        let imag = [Float](repeating: initialValue, count: count)
        let imagp = UnsafeMutablePointer<Float>.allocate(capacity: imag.count)
        imagp.assign(from: imag, count: imag.count)

        self.init(realp: realp, imagp: imagp)
    }

    /// Initialize a DSPSplitComplex with repeating values for real and imaginary splits
    ///
    /// - Parameters:
    ///   - repeatingReal: value to set real elements to
    ///   - repeatingImag: value to set imaginary elements to
    ///   - count: number of real and number of imaginary elements
    init(repeatingReal: Float, repeatingImag: Float, count: Int) {
        let real = [Float](repeating: repeatingReal, count: count)
        let realp = UnsafeMutablePointer<Float>.allocate(capacity: real.count)
        realp.assign(from: real, count: real.count)

        let imag = [Float](repeating: repeatingImag, count: count)
        let imagp = UnsafeMutablePointer<Float>.allocate(capacity: imag.count)
        imagp.assign(from: imag, count: imag.count)

        self.init(realp: realp, imagp: imagp)
    }

    func deallocate() {
        realp.deallocate()
        imagp.deallocate()
    }
}
