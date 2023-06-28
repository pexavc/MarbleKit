//
//  Model.swift
//  MarbleKit
//
//  Based on: https://github.com/kingslay/KSPlayer/blob/develop/Sources/KSPlayer/MEPlayer/Model.swift
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import CoreMedia
import Libavcodec

// MARK: enum

enum MarblePlayerSourceState {
    case idle
    case opening
    case opened
    case reading
    case seeking
    case paused
    case finished
    case closed
    case failed
}

// MARK: delegate

protocol MarblePlayerRenderSourceDelegate: AnyObject {
    func getVideoOutputRender(force: Bool) -> VideoVTBFrame?
    func getAudioOutputRender() -> AudioFrame?
    func setVideo(time: CMTime)
    func setAudio(time: CMTime)
    func setAudio(time: CMTime, frame: AudioFrame)
}

protocol MarbleCodecCapacityDelegate: AnyObject {
    func codecDidFinished(track: some CapacityProtocol)
}

protocol MarblePlayerSourceDelegate: AnyObject {
    func sourceDidChange(loadingState: LoadingState)
    func sourceDidOpened()
    func sourceDidFailed(error: NSError?)
    func sourceDidFinished()
    func sourceDidChange(oldBitRate: Int64, newBitrate: Int64)
    func sourceDidOutputAudio(buffer: AVAudioPCMBuffer?)
    func sourceIsNotInSync(videoTime: CMTime, audioTimeDesired: TimeInterval)
    func sourceClock(_ type: ClockProcessType)
    func packetReceivedFPS(_ fps: Float)
}

// MARK: protocol

public protocol MarblePacketObjectQueueItem {
    var duration: Int64 { get set }
    var position: Int64 { get set }
    var size: Int32 { get set }
}

protocol MarblePlayerFrameOutput: AnyObject {
    var renderSource: MarblePlayerRenderSourceDelegate? { get set }
}

protocol MarblePlayerFrame: MarblePacketObjectQueueItem {
    var timebase: Timebase { get set }
}

extension MarblePlayerFrame {
    public var seconds: TimeInterval { cmtime.seconds }
    public var cmtime: CMTime { timebase.cmtime(for: position) }
}

// MARK: model

// for MEPlayer
public extension MarblePlayerOptions {
    
    static var enableSensor = true
    static var stackSize = 32768
    static var isClearVideoWhereReplace = true
    
    static var isUseAudioRenderer = false
    static func colorSpace(ycbcrMatrix: CFString?, transferFunction: CFString?) -> CGColorSpace? {
        switch ycbcrMatrix {
        case kCVImageBufferYCbCrMatrix_ITU_R_709_2:
            return CGColorSpace(name: CGColorSpace.itur_709)
        case kCVImageBufferYCbCrMatrix_ITU_R_601_4:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case kCVImageBufferYCbCrMatrix_ITU_R_2020:
            if transferFunction == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ {
                if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) {
                    return CGColorSpace(name: CGColorSpace.itur_2100_PQ)
                } else {
                    return CGColorSpace(name: CGColorSpace.itur_2020)
                }
            } else if transferFunction == kCVImageBufferTransferFunction_ITU_R_2100_HLG {
                if #available(macOS 11.0, iOS 14.0, tvOS 14.0, *) {
                    return CGColorSpace(name: CGColorSpace.itur_2100_HLG)
                } else {
                    return CGColorSpace(name: CGColorSpace.itur_2020)
                }
            } else {
                return CGColorSpace(name: CGColorSpace.itur_2020)
            }

        default:
            return nil
        }
    }

    static func colorPixelFormat(bitDepth: Int32) -> MTLPixelFormat {
        if bitDepth == 10 {
            return .bgr10a2Unorm
        } else {
            return .bgra8Unorm
        }
    }
}

enum MarblePlayerCodecState {
    case idle
    case decoding
    case flush
    case closed
    case failed
    case finished
}

struct Timebase {
    static let defaultValue = Timebase(num: 1, den: 1)
    public let num: Int32
    public let den: Int32
    func getPosition(from seconds: TimeInterval) -> Int64 { Int64(seconds * TimeInterval(den) / TimeInterval(num)) }

    func cmtime(for timestamp: Int64) -> CMTime { CMTime(value: timestamp * Int64(num), timescale: den) }
}

extension Timebase {
    public var rational: AVRational { AVRational(num: num, den: den) }

    init(_ rational: AVRational) {
        num = rational.num
        den = rational.den
    }
}

final class Packet: MarblePacketObjectQueueItem {
    var duration: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    var assetTrack: FFmpegAssetTrack!
    private(set) var corePacket = av_packet_alloc()
    func fill() {
        guard let corePacket else {
            return
        }
        position = corePacket.pointee.pts == Int64.min ? corePacket.pointee.dts : corePacket.pointee.pts
        duration = corePacket.pointee.duration
        size = corePacket.pointee.size
    }

    deinit {
        av_packet_unref(corePacket)
        av_packet_free(&corePacket)
    }
}

final class SubtitleFrame: MarblePlayerFrame {
    var timebase: Timebase
    var duration: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    init(timebase: Timebase) {
        self.timebase = timebase
    }
}

public final class AudioFrame: MarblePlayerFrame {
    var timebase = Timebase.defaultValue
    public var duration: Int64 = 0
    public var position: Int64 = 0
    public var size: Int32 = 0
    var numberOfSamples: UInt32 = 0
    let channels: UInt32
    let dataSize: Int
    var data: [UnsafeMutablePointer<UInt8>?]
    public init(bufferSize: Int32, channels: UInt32, count: Int) {
        self.channels = channels
        dataSize = Int(bufferSize)
        data = (0 ..< count).map { _ in
            UnsafeMutablePointer<UInt8>.allocate(capacity: Int(bufferSize))
        }
    }

    deinit {
        for i in 0 ..< data.count {
            data[i]?.deinitialize(count: dataSize)
            data[i]?.deallocate()
        }
        data.removeAll()
    }
}

public final class VideoVTBFrame: MarblePlayerFrame {
    var timebase = Timebase.defaultValue
    public var duration: Int64 = 0
    public var position: Int64 = 0
    public var size: Int32 = 0
    var corePixelBuffer: CVPixelBuffer?
}

extension Array {
    init(tuple: (Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init([tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7])
    }

    init(tuple: (Element, Element, Element, Element)) {
        self.init([tuple.0, tuple.1, tuple.2, tuple.3])
    }

    var tuple8: (Element, Element, Element, Element, Element, Element, Element, Element) {
        (self[0], self[1], self[2], self[3], self[4], self[5], self[6], self[7])
    }

    var tuple4: (Element, Element, Element, Element) {
        (self[0], self[1], self[2], self[3])
    }
}
