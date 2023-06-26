//
//  MarblePlayerOptions.swift
//  MarbleKit
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import OSLog

open class MarblePlayerOptions {
    @Published public var preferredForwardBufferDuration = MarblePlayerOptions.preferredForwardBufferDuration

    public var maxBufferDuration = MarblePlayerOptions.maxBufferDuration
    
    public var isSecondOpen = MarblePlayerOptions.isSecondOpen
    
    public var isAccurateSeek = MarblePlayerOptions.isAccurateSeek
    /// Applies to short videos only
    public var isLoopPlay = MarblePlayerOptions.isLoopPlay
    
    public var isAutoPlay = MarblePlayerOptions.isAutoPlay
    /// Autoplay content after seek action completes
    public var isSeekedAutoPlay = MarblePlayerOptions.isSeekedAutoPlay
    public var dropVideoFrame = MarblePlayerOptions.dropVideoFrame
    public var isVideoClippingEnabled: Bool = MarblePlayerOptions.isVideoClippingEnabled
    /*
     AVSEEK_FLAG_BACKWARD: 1
     AVSEEK_FLAG_BYTE: 2
     AVSEEK_FLAG_ANY: 4
     AVSEEK_FLAG_FRAME: 8
     */
    public var seekFlags = Int32(0)
    // ffmpeg only cache http
    public var cache = false
    public var outputURL: URL?
    public var display = DisplayEnum.plane
    public var avOptions = [String: Any]()
    public var formatContextOptions = [String: Any]()
    public var decoderOptions = [String: Any]()
    public var probesize: Int64?
    public var maxAnalyzeDuration: Int64?
    public var lowres = UInt8(0)
    public var startPlayTime: TimeInterval = 0
    // audio
    public var audioDelay = 0.0 // s
    public var audioFilters = [String]()
    public var syncDecodeAudio = false
    // subtile
    public var autoSelectEmbedSubtitle = true
    public var subtitleDelay = 0.0 // s
    public var subtitleDisable = false
    public var isSeekImageSubtitle = false
    // video
    public var autoDeInterlace = false
    public var autoRotate = true
    public var destinationDynamicRange: DynamicRange?
    public var videoAdaptable = true
    public var videoFilters = [String]()
    public var syncDecodeVideo = false
    public var hardwareDecode = true
    public var asynchronousDecompression = true
    public var videoDisable = false
    public var canStartPictureInPictureAutomaticallyFromInline = true
    private var videoClockDelayCount = 0

    public internal(set) var formatName = ""
    public internal(set) var prepareTime = 0.0
    public internal(set) var dnsStartTime = 0.0
    public internal(set) var tcpStartTime = 0.0
    public internal(set) var tcpConnectedTime = 0.0
    public internal(set) var openTime = 0.0
    public internal(set) var findTime = 0.0
    public internal(set) var readyTime = 0.0
    public internal(set) var readAudioTime = 0.0
    public internal(set) var readVideoTime = 0.0
    public internal(set) var decodeAudioTime = 0.0
    public internal(set) var decodeVideoTime = 0.0
    var audioFormat = AVAudioFormat(standardFormatWithSampleRate: MarblePlayerOptions.sampleRate,
                                    channelLayout: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!)
    public init() {
        // protocols.texi && http.c for config params
        formatContextOptions["auto_convert"] = 0
        formatContextOptions["fps_probe_size"] = 3
        formatContextOptions["reconnect"] = 1
        // Enabling this will prevent playback for pure IPv6 addresses.
        //formatContextOptions["reconnect_at_eof"] = 1
        formatContextOptions["reconnect_streamed"] = 1
        formatContextOptions["reconnect_on_network_error"] = 1
        
        // There is total different meaning for 'listen_timeout' option in rtmp
        // set 'listen_timeout' = -1 for rtmp、rtsp
        formatContextOptions["listen_timeout"] = -1//3
        formatContextOptions["rw_timeout"] = 10_000_000
        formatContextOptions["user_agent"] = "MarbleKit.Player"
        decoderOptions["threads"] = "auto"
        decoderOptions["refcounted_frames"] = "1"
    }

    /**
     you can add http-header or other options which mentions in https://developer.apple.com/reference/avfoundation/avurlasset/initialization_options

     to add http-header init options like this
     ```
     options.appendHeader(["Referer":"site_url"])
     ```
     */
    public func appendHeader(_ header: [String: String]) {
        var oldValue = avOptions["AVURLAssetHTTPHeaderFieldsKey"] as? [String: String] ?? [
            String: String
        ]()
        oldValue.merge(header) { _, new in new }
        avOptions["AVURLAssetHTTPHeaderFieldsKey"] = oldValue
        var str = formatContextOptions["headers"] as? String ?? ""
        for (key, value) in header {
            str.append("\(key):\(value)\r\n")
        }
        formatContextOptions["headers"] = str
    }

    public func setCookie(_ cookies: [HTTPCookie]) {
        avOptions[AVURLAssetHTTPCookiesKey] = cookies
        let cookieStr = cookies.map { cookie in "\(cookie.name)=\(cookie.value)" }.joined(separator: "; ")
        appendHeader(["Cookie": cookieStr])
    }

    // Buffering algorithm function
    open func playable(capacitys: [CapacityProtocol],
                       isFirst: Bool,
                       isSeek: Bool) -> LoadingState {
        let packetCount = capacitys.map(\.packetCount).min() ?? 0
        let frameCount = capacitys.map(\.frameCount).min() ?? 0
        let isEndOfFile = capacitys.allSatisfy(\.isEndOfFile)
        let loadedTime = capacitys.map { TimeInterval($0.packetCount + $0.frameCount) / TimeInterval($0.fps) }.min() ?? 0
        let progress = loadedTime * 100.0 / preferredForwardBufferDuration
        let isPlayable = capacitys.allSatisfy { capacity in
            if capacity.isEndOfFile && capacity.packetCount == 0 {
                return true
            }
            guard capacity.frameCount >= capacity.frameMaxCount >> 2 else {
                return false
            }
            if capacity.isEndOfFile {
                return true
            }
            if (syncDecodeVideo && capacity.mediaType == .video) || (syncDecodeAudio && capacity.mediaType == .audio) {
                return true
            }
            if isFirst || isSeek {
                // pure audio syncs faster
                if capacity.mediaType == .audio || isSecondOpen {
                    if isFirst {
                        return true
                    } else if isSeek, capacity.packetCount >= Int(capacity.fps) {
                        return true
                    }
                }
            }
            return capacity.packetCount + capacity.frameCount >= Int(capacity.fps * Float(preferredForwardBufferDuration))
        }
        return LoadingState(loadedTime: loadedTime, progress: progress, packetCount: packetCount,
                            frameCount: frameCount, isEndOfFile: isEndOfFile, isPlayable: isPlayable,
                            isFirst: isFirst, isSeek: isSeek)
    }

    open func adaptable(state: VideoAdaptationState?) -> (Int64, Int64)? {
        guard let state, let last = state.bitRateStates.last, CACurrentMediaTime() - last.time > maxBufferDuration / 2, let index = state.bitRates.firstIndex(of: last.bitRate) else {
            return nil
        }
        let isUp = state.loadedCount > Int(Double(state.fps) * maxBufferDuration / 2)
        if isUp != state.isPlayable {
            return nil
        }
        if isUp {
            if index < state.bitRates.endIndex - 1 {
                return (last.bitRate, state.bitRates[index + 1])
            }
        } else {
            if index > state.bitRates.startIndex {
                return (last.bitRate, state.bitRates[index - 1])
            }
        }
        return nil
    }

    ///  wanted video stream index, or nil for automatic selection
    /// - Parameter : video bitRate
    /// - Returns: The index of the bitRates
    open func wantedVideo(bitRates _: [Int64]) -> Int? {
        nil
    }

    /// wanted audio stream index, or nil for automatic selection
    /// - Parameter :  audio bitRate and language
    /// - Returns: The index of the infos
    open func wantedAudio(infos _: [(bitRate: Int64, language: String?)]) -> Int? {
        nil
    }

    open func videoFrameMaxCount(fps: Float) -> Int {
        Int(ceil(fps)) >> 1
    }

    open func audioFrameMaxCount(fps _: Float, channels: Int) -> Int {
        (16 * max(channels, 1)) >> 1
    }

    /// customize dar
    /// - Parameters:
    ///   - sar: SAR(Sample Aspect Ratio)
    ///   - dar: PAR(Pixel Aspect Ratio)
    /// - Returns: DAR(Display Aspect Ratio)
    open func customizeDar(sar _: CGSize, par _: CGSize) -> CGSize? {
        nil
    }

    open func isUseDisplayLayer() -> Bool {
        display == .plane
    }

    private var idetTypeMap = [VideoInterlacingType: Int]()
    @Published public var videoInterlacingType: VideoInterlacingType?
    public enum VideoInterlacingType: String {
        case tff
        case bff
        case progressive
        case undetermined
    }

    open func io(log: String) {
        if log.starts(with: "Original list of addresses"), dnsStartTime == 0 {
            dnsStartTime = CACurrentMediaTime()
        } else if log.starts(with: "Starting connection attempt to"), tcpStartTime == 0 {
            tcpStartTime = CACurrentMediaTime()
        } else if log.starts(with: "Successfully connected to"), tcpConnectedTime == 0 {
            tcpConnectedTime = CACurrentMediaTime()
        }
    }

    open func filter(log: String) {
        if log.starts(with: "Repeated Field:") {
            log.split(separator: ",").forEach { str in
                let map = str.split(separator: ":")
                if map.count >= 2 {
                    if String(map[0].trimmingCharacters(in: .whitespaces)) == "Multi frame" {
                        if let type = VideoInterlacingType(rawValue: map[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                            idetTypeMap[type] = (idetTypeMap[type] ?? 0) + 1
                            let tff = idetTypeMap[.tff] ?? 0
                            let bff = idetTypeMap[.bff] ?? 0
                            let progressive = idetTypeMap[.progressive] ?? 0
                            let undetermined = idetTypeMap[.undetermined] ?? 0
                            if progressive - tff - bff > 100 {
                                videoInterlacingType = .progressive
                                autoDeInterlace = false
                            } else if bff - progressive > 100 {
                                videoInterlacingType = .bff
                                autoDeInterlace = false
                            } else if tff - progressive > 100 {
                                videoInterlacingType = .tff
                                autoDeInterlace = false
                            } else if undetermined - progressive - tff - bff > 100 {
                                videoInterlacingType = .undetermined
                                autoDeInterlace = false
                            }
                        }
                    }
                }
            }
        }
    }

    open func sei(string: String) {
        MarblePlayerLog("sei \(string)")
    }

    /*
     Before creating the decoder, some processing can be done on MarblePlayerOptions. For example, if the fieldOrder is tt or bb, then videofilters will be automatically added.
     */
    open func process(assetTrack _: MediaPlayerTrack) {}

    #if os(tvOS)
    open func preferredDisplayCriteria(refreshRate _: Float,
                                       videoDynamicRange _: Int32) -> AVDisplayCriteria? {
        nil
    }
    #endif

    open func setAudioSession(audioDescriptor: AudioDescriptor) {
        #if os(macOS)
        let channels = AVAudioChannelCount(2)
        #else
        MarblePlayerOptions.setAudioSession()
        let isSpatialAudioEnabled: Bool
        if #available(tvOS 15.0, iOS 15.0, *) {
            isSpatialAudioEnabled = AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.isSpatialAudioEnabled }
            try? AVAudioSession.sharedInstance().setSupportsMultichannelContent(isSpatialAudioEnabled)
        } else {
            isSpatialAudioEnabled = false
        }
        var channels = audioDescriptor.channels
        if channels > 2 {
            let minChannels = min(AVAudioChannelCount(AVAudioSession.sharedInstance().maximumOutputNumberOfChannels), channels)
            try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(Int(minChannels))
            if !isSpatialAudioEnabled {
                channels = AVAudioChannelCount(AVAudioSession.sharedInstance().preferredOutputNumberOfChannels)
            }
        } else {
            try? AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(2)
        }
        #endif
        audioFormat = audioDescriptor.audioFormat(channels: channels)
    }

    open func videoClockSync(audioTime: TimeInterval, videoTime: TimeInterval) -> ClockProcessType {
        let delay = audioTime - videoTime
        if delay > 0.4 {
            MarblePlayerLog("video delay time: \(delay), audio time:\(audioTime), delay count:\(videoClockDelayCount)")
            if delay > 2 {
                videoClockDelayCount += 1
                if videoClockDelayCount > 10 {
                    MarblePlayerLog("seek video track")
                    return .seek
                } else {
                    return .drop
                }
            } else {
                return .drop
            }
        } else {
            videoClockDelayCount = 0
            return .show
        }
    }

    func availableDynamicRange(_ cotentRange: DynamicRange?) -> DynamicRange? {
        #if canImport(UIKit)
        let availableHDRModes = AVPlayer.availableHDRModes
        if let preferedDynamicRange = destinationDynamicRange {
            // value of 0 indicates that no HDR modes are supported.
            if availableHDRModes == AVPlayer.HDRMode(rawValue: 0) {
                return .sdr
            } else if availableHDRModes.contains(preferedDynamicRange.hdrMode) {
                return preferedDynamicRange
            } else if let cotentRange,
                      availableHDRModes.contains(cotentRange.hdrMode)
            {
                return cotentRange
            } else if preferedDynamicRange != .sdr { // trying update to HDR mode
                return availableHDRModes.dynamicRange
            }
        }
        #endif
        return cotentRange
    }
}

public extension MarblePlayerOptions {
    static var firstPlayerType: MarblePlayerProtocol.Type = MarblePlayer.self
    static var secondPlayerType: MarblePlayerProtocol.Type?
    /// Minimum video caching time.
    static var preferredForwardBufferDuration = 12.0
    /// Maximum video caching time.
    static var maxBufferDuration = 48.0
    /// Instant Playback
    static var isSecondOpen = false
    
    static var isAccurateSeek = false
    /// Applies to short videos only
    static var isLoopPlay = false
    
    static var isAutoPlay = false
    
    /// Autoplay after completed seeking
    static var isSeekedAutoPlay = true
    
    static var dropVideoFrame = true
    
    static var isVideoClippingEnabled = true
    
    static var logLevel = LogLevel.warning
    
    static var preferredFramesPerSecond: Int = 30
    
    static var sampleRate: Double = 44100
    
    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    static var logger = Logger()

    internal static func deviceCpuCount() -> Int {
        var ncpu = UInt(0)
        var len: size_t = MemoryLayout.size(ofValue: ncpu)
        sysctlbyname("hw.ncpu", &ncpu, &len, nil, 0)
        return Int(ncpu)
    }

    internal static func setAudioSession() {
        #if os(macOS)
        
        #else
        let category = AVAudioSession.sharedInstance().category
        if category != .playback, category != .playAndRecord {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
        }
        try? AVAudioSession.sharedInstance().setMode(.moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}

extension LogLevel {
    var logType: OSLogType {
        switch self {
        case .panic, .fatal:
            return .fault
        case .error:
            return .error
        case .warning:
            return .debug
        case .info, .verbose, .debug:
            return .info
        case .trace:
            return .default
        }
    }
}

@inline(__always) public func MarblePlayerLog(level: LogLevel = .warning, dso: UnsafeRawPointer = #dsohandle, _ message: StaticString, _ args: CVarArg...) {
    if level.rawValue <= MarblePlayerOptions.logLevel.rawValue {
        os_log(level.logType, dso: dso, message, args)
    }
}
