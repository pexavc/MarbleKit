//
//  Decoder.swift
//  MarbleKit.Player
//
//  Created by kintan on 2018/3/9.
//
import AVFoundation
import CoreMedia
import Libavformat

protocol PlayerItemTrackProtocol: CapacityProtocol, AnyObject {
    init(assetTrack: FFmpegAssetTrack, options: MarblePlayerOptions)
    
    var isLoopModel: Bool { get set }
    var isEndOfFile: Bool { get set }
    var delegate: MarbleCodecCapacityDelegate? { get set }
    func decode()
    func seek(time: TimeInterval)
    func putPacket(packet: Packet)
    func shutdown()
}

class SyncPlayerItemTrack<Frame: MarblePlayerFrame>: PlayerItemTrackProtocol, CustomStringConvertible {
    var seekTime = 0.0
    fileprivate let options: MarblePlayerOptions
    fileprivate var decoderMap = [Int32: DecodeProtocol]()
    fileprivate var state = MarblePlayerCodecState.idle {
        didSet {
            if state == .finished {
                seekTime = 0
            }
        }
    }

    var isEndOfFile: Bool = false
    var packetCount: Int { 0 }
    var frameCount: Int { outputRenderQueue.count }
    let frameMaxCount: Int
    let description: String
    weak var delegate: MarbleCodecCapacityDelegate?
    let fps: Float
    let mediaType: AVFoundation.AVMediaType
    let outputRenderQueue: CircularBuffer<Frame>
    var isLoopModel = false

    required init(assetTrack: FFmpegAssetTrack, options: MarblePlayerOptions) {
        self.options = options
        options.process(assetTrack: assetTrack)
        mediaType = assetTrack.mediaType
        description = mediaType.rawValue
        fps = assetTrack.nominalFrameRate
        
        // circular buffer cache sizes
        // max audioFrame == (16 * max(channels, 1)) >> 1
        // max videoFrame == fps >> 1
        if mediaType == .audio {
            let capacity = options.audioFrameMaxCount(fps: fps, channels: Int(assetTrack.audioDescriptor.channels))
            outputRenderQueue = CircularBuffer(initialCapacity: capacity, expanding: false)
        } else if mediaType == .video {
            outputRenderQueue = CircularBuffer(initialCapacity: options.videoFrameMaxCount(fps: fps), sorted: true, expanding: false)
        } else {
            outputRenderQueue = CircularBuffer()
        }
        frameMaxCount = outputRenderQueue.maxCount
    }

    func decode() {
        isEndOfFile = false
        state = .decoding
    }

    func seek(time: TimeInterval) {
        if options.isAccurateSeek {
            seekTime = time
        }
        isEndOfFile = false
        state = .flush
        outputRenderQueue.flush()
        isLoopModel = false
    }

    func putPacket(packet: Packet) {
        if state == .flush {
            decoderMap.values.forEach { $0.doFlushCodec() }
            state = .decoding
        }
        if state == .decoding {
            doDecode(packet: packet)
        }
    }

    func getOutputRender(where predicate: ((Frame) -> Bool)?) -> Frame? {
        let outputFecthRender = outputRenderQueue.pop(where: predicate)
        if outputFecthRender == nil {
            if state == .finished, frameCount == 0 {
                delegate?.codecDidFinished(track: self)
            }
        }
        return outputFecthRender
    }
    
    func searchRender(where predicate: ((Frame) -> Bool)) -> Frame? {
        return outputRenderQueue.search(where: predicate)
    }

    func shutdown() {
        if state == .idle {
            return
        }
        state = .closed
        outputRenderQueue.shutdown()
    }

    fileprivate func doDecode(packet: Packet) {
        let decoder = decoderMap.value(for: packet.assetTrack.trackID, default: makeDecode(assetTrack: packet.assetTrack))
        decoder.decodeFrame(from: packet) { [weak self] result in
            guard let self else {
                return
            }
            do {
                let frame = try result.get()
                if self.state == .flush || self.state == .closed {
                    return
                }
                if self.seekTime > 0 {
                    let timestamp = frame.position + frame.duration
                    if timestamp <= 0 || frame.timebase.cmtime(for: timestamp).seconds < self.seekTime {
                        return
                    } else {
                        self.seekTime = 0.0
                    }
                }
                if let frame = frame as? Frame {
                    self.outputRenderQueue.push(frame)
                }
            } catch {
                MarblePlayerLog("Decoder did Failed : \(error)")
                if decoder is VideoToolboxDecode {
                    decoder.shutdown()
                    self.decoderMap[packet.assetTrack.trackID] = FFmpegDecode(assetTrack: packet.assetTrack, options: self.options)
                    MarblePlayerLog("VideoCodec switch to software decompression")
                    self.doDecode(packet: packet)
                } else {
                    self.state = .failed
                }
            }
        }
        if options.decodeAudioTime == 0, mediaType == .audio {
            options.decodeAudioTime = CACurrentMediaTime()
        }
        if options.decodeVideoTime == 0, mediaType == .video {
            options.decodeVideoTime = CACurrentMediaTime()
        }
    }
}

final class AsyncPlayerItemTrack<Frame: MarblePlayerFrame>: SyncPlayerItemTrack<Frame> {
    private let operationQueue = OperationQueue()
    private var decodeOperation: BlockOperation!
    
    // along with circular buffers, packets are queued for insertion
    private var loopPacketQueue: CircularBuffer<Packet>?
    private var packetQueue = CircularBuffer<Packet>()
    override var packetCount: Int { packetQueue.count }
    override var isLoopModel: Bool {
        didSet {
            if isLoopModel {
                loopPacketQueue = CircularBuffer<Packet>()
                isEndOfFile = true
            } else {
                if let loopPacketQueue {
                    packetQueue.shutdown()
                    packetQueue = loopPacketQueue
                    self.loopPacketQueue = nil
                    if decodeOperation.isFinished {
                        decode()
                    }
                }
            }
        }
    }

    required init(assetTrack: FFmpegAssetTrack, options: MarblePlayerOptions) {
        super.init(assetTrack: assetTrack, options: options)
        operationQueue.name = "MarbleKit.Player_" + description
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
    }

    override func putPacket(packet: Packet) {
        if isLoopModel {
            loopPacketQueue?.push(packet)
        } else {
            packetQueue.push(packet)
        }
    }

    override func decode() {
        isEndOfFile = false
        guard operationQueue.operationCount == 0 else { return }
        decodeOperation = BlockOperation { [weak self] in
            guard let self else { return }
            Thread.current.name = self.operationQueue.name
            Thread.current.stackSize = MarblePlayerOptions.stackSize
            self.decodeThread()
        }
        decodeOperation.queuePriority = .veryHigh
        decodeOperation.qualityOfService = .userInteractive
        operationQueue.addOperation(decodeOperation)
    }

    private func decodeThread() {
        state = .decoding
        isEndOfFile = false
        decoderMap.values.forEach { $0.decode() }
        outerLoop: while !decodeOperation.isCancelled {
            switch state {
            case .idle:
                break outerLoop
            case .finished, .closed, .failed:
                decoderMap.values.forEach { $0.shutdown() }
                decoderMap.removeAll()
                break outerLoop
            case .flush:
                decoderMap.values.forEach { $0.doFlushCodec() }
                state = .decoding
            case .decoding:
                if isEndOfFile, packetQueue.count == 0 {
                    state = .finished
                } else {
                    guard let packet = packetQueue.pop(wait: true), state != .flush, state != .closed else {
                        continue
                    }
                    autoreleasepool {
                        doDecode(packet: packet)
                    }
                }
            }
        }
    }

    override func seek(time: TimeInterval) {
        if decodeOperation.isFinished {
            decode()
        }
        packetQueue.flush()
        super.seek(time: time)
        loopPacketQueue = nil
    }

    override func shutdown() {
        if state == .idle {
            return
        }
        super.shutdown()
        packetQueue.shutdown()
    }
}

public extension Dictionary {
    mutating func value(for key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        if let value = self[key] {
            return value
        } else {
            let value = defaultValue()
            self[key] = value
            return value
        }
    }
}

protocol DecodeProtocol {
    init(assetTrack: FFmpegAssetTrack, options: MarblePlayerOptions)
    func decode()
    func decodeFrame(from packet: Packet, completionHandler: @escaping (Result<MarblePlayerFrame, Error>) -> Void)
    func doFlushCodec()
    func shutdown()
}

extension SyncPlayerItemTrack {
    func makeDecode(assetTrack: FFmpegAssetTrack) -> DecodeProtocol {
        autoreleasepool {
            if mediaType == .subtitle {
                return FFmpegDecode(assetTrack: assetTrack, options: options)
            } else {
                if mediaType == .video, options.asynchronousDecompression, options.hardwareDecode,
                   let session = DecompressionSession(codecpar: assetTrack.codecpar, options: options)
                {
                    return VideoToolboxDecode(assetTrack: assetTrack, options: options, session: session)
                } else {
                    return FFmpegDecode(assetTrack: assetTrack, options: options)
                }
            }
        }
    }
}
