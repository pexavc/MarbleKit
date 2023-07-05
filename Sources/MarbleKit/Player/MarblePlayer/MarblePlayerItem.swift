//
//  MarblePlayerItem.swift
//  MarbleKit.Player
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import FFmpegKit
import Libavcodec
import Libavfilter
import Libavformat

final class MarblePlayerItem {
    internal let url: URL
    internal let options: MarblePlayerOptions
    private let operationQueue = OperationQueue()
    private var setAudioOperationQueue: OperationQueue = .init()
    private var probeCodecOperationQueue: OperationQueue = .init()
    private let condition = NSCondition()
    internal var formatCtx: UnsafeMutablePointer<AVFormatContext>?
    internal var altFormatCtx: UnsafeMutablePointer<AVFormatContext>?
    internal var outputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
    internal var outputPacket: UnsafeMutablePointer<AVPacket>?
    internal var streamMapping = [Int: Int]()
    internal var openOperation: BlockOperation?
    internal var readOperation: BlockOperation?
    internal var closeOperation: BlockOperation?
    internal var seekingCompletionHandler: ((Bool) -> Void)?
    // No audio data found
    internal var isAudioStalled = true
    internal var videoMediaTime = CACurrentMediaTime()
    internal var isFirst = true
    internal var isSeek = false
    internal var allPlayerItemTracks = [PlayerItemTrackProtocol]()
    internal var videoAudioTracks: [CapacityProtocol] {
        var tracks = [CapacityProtocol]()
        if let audioTrack {
            tracks.append(audioTrack)
        }
        if !options.videoDisable, let videoTrack {
            tracks.append(videoTrack)
        }
        return tracks
    }

    internal var videoTrack: SyncPlayerItemTrack<VideoVTBFrame>?
    internal var audioTrack: SyncPlayerItemTrack<AudioFrame>?
    private(set) var assetTracks = [FFmpegAssetTrack]()
    internal var videoAdaptation: VideoAdaptationState?
    private(set) var currentPlaybackTime = TimeInterval(0)
    private(set) var startTime = TimeInterval(0)
    private(set) var duration: TimeInterval = 0
    private(set) var naturalSize = CGSize.zero
    internal var lastProbedFPS: Float = 0
    
    //TODO: meant for in-sync AVisuals
    internal var lastAudioFrame: AudioFrame? = nil
    
    //Caching audio renders
    internal var audioClip: AudioClip = .init()
    
    internal var error: NSError? {
        didSet {
            if error != nil {
                state = .failed
            }
        }
    }

    internal var state = MarblePlayerSourceState.idle {
        didSet {
            switch state {
            case .opened:
                delegate?.sourceDidOpened()
            case .reading:
                timer.fireDate = Date.distantPast
                timerProbeCodec.fireDate = Date.distantPast
            case .closed:
                timer.invalidate()
                timerProbeCodec.invalidate()
            case .failed:
                delegate?.sourceDidFailed(error: error)
                timer.fireDate = Date.distantFuture
                timerProbeCodec.fireDate = Date.distantFuture
            case .idle, .opening, .seeking, .paused, .finished, .restarting:
                break
            }
        }
    }

    private lazy var timer: Timer = .scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
        self?.codecDidChangeCapacity()
    }
    
    internal lazy var timerProbeCodec: Timer = .scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
        self?.probeCodecOperationQueue.addOperation { [weak self] in
            self?.probeCodec()
        }
    }

    private lazy var onceInitial: Void = {
        //Moved to a static call in MarbleRemote `initializeNetwork`
        //avformat_network_init()
        av_log_set_callback { ptr, level, format, args in
            guard let format else {
                return
            }
            var log = String(cString: format)
            let arguments: CVaListPointer? = args
            if let arguments {
                log = NSString(format: log, arguments: arguments) as String
            }
            if let ptr {
                let avclass = ptr.assumingMemoryBound(to: UnsafePointer<AVClass>.self).pointee
                if avclass.pointee.category == AV_CLASS_CATEGORY_NA, avclass == &ffurl_context_class {
                    let context = ptr.assumingMemoryBound(to: URLContext.self).pointee
                    if let opaque = context.interrupt_callback.opaque {
                        let playerItem = Unmanaged<MarblePlayerItem>.fromOpaque(opaque).takeUnretainedValue()
                        playerItem.options.io(log: log)
                        if log.starts(with: "Will reconnect at") {
                            playerItem.videoTrack?.seekTime = playerItem.currentPlaybackTime
                            playerItem.audioTrack?.seekTime = playerItem.currentPlaybackTime
                        }
                    }
                } else if avclass == avfilter_get_class() {
                    let context = ptr.assumingMemoryBound(to: AVFilterContext.self).pointee
                    if let opaque = context.graph?.pointee.opaque {
                        let options = Unmanaged<MarblePlayerOptions>.fromOpaque(opaque).takeUnretainedValue()
                        options.filter(log: log)
                    }
                }
            }
            
            if log.hasPrefix("parser not found for codec") {
                MarblePlayerLog(log)
            }
            MarblePlayerLog(log, logLevel: LogLevel(rawValue: level) ?? .warning)
        }
    }()

    weak var delegate: MarblePlayerSourceDelegate?
    
    init(url: URL, options: MarblePlayerOptions) {
        self.url = url
        self.options = options
        timer.fireDate = Date.distantFuture
        timerProbeCodec.fireDate = Date.distantFuture
        operationQueue.name = "marblekit.playeritem.read.queue_" + String(describing: self).components(separatedBy: ".").last!
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInteractive
        
        //TODO: check/remove
        setAudioOperationQueue.name = "marblekit.playeritem.setAudio.queue"
        setAudioOperationQueue.maxConcurrentOperationCount = 1
        setAudioOperationQueue.qualityOfService = .userInteractive
        
        probeCodecOperationQueue.name = "marblekit.probeCodec.queue"
        probeCodecOperationQueue.maxConcurrentOperationCount = 1
        probeCodecOperationQueue.qualityOfService = .background
        
        _ = onceInitial
    }

    func select(track: MediaPlayerTrack) {
        if track.isEnabled {
            return
        }
        assetTracks.filter { $0.mediaType == track.mediaType }.forEach {
            if $0.mediaType == .subtitle, !$0.isImageSubtitle {
                return
            }
            $0.isEnabled = false
        }
        track.isEnabled = true
        guard let assetTrack = track as? FFmpegAssetTrack else {
            return
        }
        if assetTrack.mediaType == .video {
            findBestAudio(videoTrack: assetTrack)
        } else if assetTrack.mediaType == .subtitle {
            if assetTrack.isImageSubtitle {
                if !options.isSeekImageSubtitle {
                    return
                }
            } else {
                return
            }
        }
        seek(time: currentPlaybackTime) { _ in
        }
    }
}

// MARK: private functions

extension MarblePlayerItem {
    internal func openThread() {
        avformat_close_input(&self.formatCtx)
        formatCtx = avformat_alloc_context()
        guard let formatCtx else {
            error = NSError(errorCode: .formatCreate)
            return
        }
        var interruptCB = AVIOInterruptCB()
        interruptCB.opaque = Unmanaged.passUnretained(self).toOpaque()
        interruptCB.callback = { ctx -> Int32 in
            guard let ctx else {
                return 0
            }
            let formatContext = Unmanaged<MarblePlayerItem>.fromOpaque(ctx).takeUnretainedValue()
            switch formatContext.state {
            case .finished, .closed, .failed, .restarting:
                return 1
            default:
                return 0
            }
        }
        formatCtx.pointee.interrupt_callback = interruptCB
//        formatCtx.pointee.io_close2 = { formatCtx, pb -> Int32 in
//            return 0
//
//        }
//        formatCtx.pointee.io_open = { formatCtx, context, url, flags, options -> Int32 in
//            return 0
//        }
        var avOptions = options.formatContextOptions.avOptions
        let urlString: String
        if url.isFileURL {
            urlString = url.path
        } else {
            if url.absoluteString.hasPrefix("https") || !options.cache {
                urlString = url.absoluteString
            } else {
                urlString = "async:cache:" + url.absoluteString
            }
        }
        // If you want to customize the protocol, use avio_alloc_context to assign the value to formatCtx.pointee.pb.
        var result = avformat_open_input(&self.formatCtx, urlString, nil, &avOptions)
        av_dict_free(&avOptions)
        if result == AVError.eof.code {
            state = .finished
            delegate?.sourceDidFinished()
            return
        }
        guard result == 0 else {
            error = .init(errorCode: .formatOpenInput, avErrorCode: result)
            avformat_close_input(&self.formatCtx)
            return
        }
        options.openTime = CACurrentMediaTime()
        formatCtx.pointee.flags |= AVFMT_FLAG_GENPTS
        av_format_inject_global_side_data(formatCtx)
        if let probesize = options.probesize {
            formatCtx.pointee.probesize = probesize
        }
        if let maxAnalyzeDuration = options.maxAnalyzeDuration {
            formatCtx.pointee.max_analyze_duration = maxAnalyzeDuration
        }
        result = avformat_find_stream_info(formatCtx, nil)
        guard result == 0 else {
            error = .init(errorCode: .formatFindStreamInfo, avErrorCode: result)
            avformat_close_input(&self.formatCtx)
            return
        }
        options.findTime = CACurrentMediaTime()
        options.formatName = String(cString: formatCtx.pointee.iformat.pointee.name)
        if formatCtx.pointee.start_time != Int64.min {
            startTime = CMTime(value: formatCtx.pointee.start_time, timescale: AV_TIME_BASE).seconds
        }
        currentPlaybackTime = startTime
        duration = TimeInterval(max(formatCtx.pointee.duration, 0) / Int64(AV_TIME_BASE))
        if duration > startTime {
            duration -= startTime
        }
        createCodec(formatCtx: formatCtx)
        if let outputURL = options.outputURL {
            openOutput(url: outputURL)
        }
        if videoTrack == nil, audioTrack == nil {
            state = .failed
        } else {
            state = .opened
            read()
        }
    }

    internal func createCodec(formatCtx: UnsafeMutablePointer<AVFormatContext>) {
        allPlayerItemTracks.removeAll()
        assetTracks.removeAll()
        videoAdaptation = nil
        videoTrack = nil
        audioTrack = nil
        assetTracks = (0 ..< Int(formatCtx.pointee.nb_streams)).compactMap { i in
            if let coreStream = formatCtx.pointee.streams[i] {
                coreStream.pointee.discard = AVDISCARD_ALL
                if let assetTrack = FFmpegAssetTrack(stream: coreStream) {
                    assetTrack.startTime = startTime
                    if !options.subtitleDisable, assetTrack.mediaType == .subtitle {
                        let subtitle = SyncPlayerItemTrack<SubtitleFrame>(assetTrack: assetTrack, options: options)
                        assetTrack.isEnabled = !assetTrack.isImageSubtitle
                        assetTrack.subtitle = subtitle
                        allPlayerItemTracks.append(subtitle)
                    }
                    return assetTrack
                }
            }
            return nil
        }
        if options.autoSelectEmbedSubtitle {
            assetTracks.first { $0.mediaType == .subtitle }?.isEnabled = true
        }
        var videoIndex: Int32 = -1
        if !options.videoDisable {
            let videos = assetTracks.filter { $0.mediaType == .video }
            let bitRates = videos.map(\.bitRate)
            let wantedStreamNb: Int32
            if videos.count > 0, let index = options.wantedVideo(bitRates: bitRates) {
                wantedStreamNb = videos[index].trackID
            } else {
                wantedStreamNb = -1
            }
            videoIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, wantedStreamNb, -1, nil, 0)
            if let first = videos.first(where: { $0.trackID == videoIndex }) {
                first.isEnabled = true
                
                let rotation = first.rotation
                
                if rotation > 0, options.autoRotate {
                    options.hardwareDecode = false
                    if abs(rotation - 90) <= 1 {
                        options.videoFilters.append("transpose=clock")
                    } else if abs(rotation - 180) <= 1 {
                        options.videoFilters.append("hflip")
                        options.videoFilters.append("vflip")
                    } else if abs(rotation - 270) <= 1 {
                        options.videoFilters.append("transpose=cclock")
                    } else if abs(rotation) > 1 {
                        options.videoFilters.append("rotate=\(rotation)*PI/180")
                    }
                }
                
                naturalSize = abs(rotation - 90) <= 1 || abs(rotation - 270) <= 1 ? first.naturalSize.reverse : first.naturalSize
                
                let track = options.syncDecodeVideo ? SyncPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<VideoVTBFrame>(assetTrack: first, options: options)
                
                track.delegate = self
                allPlayerItemTracks.append(track)
                videoTrack = track
                
                if videos.count > 1, options.videoAdaptable {
                    let bitRateState = VideoAdaptationState.BitRateState(bitRate: first.bitRate, time: CACurrentMediaTime())
                    videoAdaptation = VideoAdaptationState(bitRates: bitRates.sorted(by: <), duration: duration, fps: first.nominalFrameRate, bitRateStates: [bitRateState])
                }
            }
        }

        let audios = assetTracks.filter { $0.mediaType == .audio }
        let wantedStreamNb: Int32
        if audios.count > 0, let index = options.wantedAudio(infos: audios.map { ($0.bitRate, $0.language) }) {
            wantedStreamNb = audios[index].trackID
        } else {
            wantedStreamNb = -1
        }
        let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, wantedStreamNb, videoIndex, nil, 0)
        if let first = audios.first(where: {
            index > 0 ? $0.trackID == index : true
        }) {
            first.isEnabled = true
            let track = options.syncDecodeAudio ? SyncPlayerItemTrack<AudioFrame>(assetTrack: first, options: options) : AsyncPlayerItemTrack<AudioFrame>(assetTrack: first, options: options)
            track.delegate = self
            allPlayerItemTracks.append(track)
            audioTrack = track
            isAudioStalled = false
        }
    }

    private func read() {
        readOperation = BlockOperation { [weak self] in
            guard let self else { return }
            Thread.current.name = (self.operationQueue.name ?? "") + "_read"
            Thread.current.stackSize = MarblePlayerOptions.stackSize
            self.readThread()
        }
        readOperation?.queuePriority = .veryHigh
        readOperation?.qualityOfService = .userInteractive
        if let readOperation {
            operationQueue.addOperation(readOperation)
        }
    }

    private func readThread() {
        if state == .opened {
            if options.startPlayTime > 0 {
                currentPlaybackTime = options.startPlayTime
                state = .seeking
            } else {
                state = .reading
            }
        }
        allPlayerItemTracks.forEach { $0.decode() }
        while [MarblePlayerSourceState.paused, .seeking, .reading].contains(state) {
            if state == .paused {
                condition.wait()
            }
            if state == .seeking {
                let time = currentPlaybackTime
                let timeStamp = Int64(time * TimeInterval(AV_TIME_BASE))
                let startTime = CACurrentMediaTime()
                // can not seek to key frame
//                let result = avformat_seek_file(formatCtx, -1, Int64.min, timeStamp, Int64.max, options.seekFlags)
                var result = av_seek_frame(formatCtx, -1, timeStamp, options.seekFlags)
                // When seeking before the beginning of the file, and seeking fails,
                // try again without the backwards flag to make it seek to the
                // beginning.
                if result < 0, options.seekFlags & AVSEEK_FLAG_BACKWARD > 0 {
                    options.seekFlags &= ~AVSEEK_FLAG_BACKWARD
                    result = av_seek_frame(formatCtx, -1, timeStamp, options.seekFlags)
                }
                MarblePlayerLog("seek to \(time) spend Time: \(CACurrentMediaTime() - startTime)")
                if state == .closed || state == .restarting {
                    break
                }
                isSeek = true
                allPlayerItemTracks.forEach { $0.seek(time: time) }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.seekingCompletionHandler?(result >= 0)
                    self.seekingCompletionHandler = nil
                }
                state = .reading
            } else if state == .reading {
                autoreleasepool {
                    reading()
                }
            }
        }
    }

    internal func pause() {
        if state == .reading {
            state = .paused
        }
    }

    internal func resume() {
        if state == .paused {
            state = .reading
            condition.signal()
        }
    }
}

extension MarblePlayerItem {
    var metadata: [String: String] {
        toDictionary(formatCtx?.pointee.metadata)
    }

    var bytesRead: Int64 {
        formatCtx?.pointee.pb.pointee.bytes_read ?? 0
    }
}

// MARK: MarbleMediaPlayback

extension MarblePlayerItem: MarbleMediaPlayback {
    var seekable: Bool {
        guard let formatCtx else {
            return false
        }
        var seekable = true
        if let ioContext = formatCtx.pointee.pb {
            seekable = ioContext.pointee.seekable > 0
        }
        return seekable && duration > 0
    }

    func prepareToPlay() {
        state = .opening
        openOperation = BlockOperation { [weak self] in
            guard let self else { return }
            Thread.current.name = (self.operationQueue.name ?? "") + "_open"
            Thread.current.stackSize = MarblePlayerOptions.stackSize
            self.openThread()
        }
        openOperation?.queuePriority = .veryHigh
        openOperation?.qualityOfService = .userInteractive
        if let openOperation {
            operationQueue.addOperation(openOperation)
        }
    }

    func shutdown(restart: Bool) {
        guard state != .closed && state != .restarting else { return }
        
        self.timerProbeCodec.fireDate = Date.distantFuture
        
        state = restart ? .restarting : .closed
        av_packet_free(&outputPacket)
        if let outputFormatCtx {
            av_write_trailer(outputFormatCtx)
        }
        // Intentionally creating circular reference. The memory will be released only after it's complete.
        let closeOperation = BlockOperation {
            Thread.current.name = (self.operationQueue.name ?? "") + "_close"
            self.allPlayerItemTracks.forEach { $0.shutdown() }
            MarblePlayerLog("formatCtx")
            self.formatCtx?.pointee.interrupt_callback.opaque = nil
            self.formatCtx?.pointee.interrupt_callback.callback = nil
            avformat_close_input(&self.formatCtx)
            avformat_close_input(&self.outputFormatCtx)
            
            //avformat_close_input should be calling free_context within
            //https://ffmpeg.org/doxygen/4.1/libavformat_2utils_8c_source.html#l04427
            avformat_free_context(self.formatCtx)
            avformat_free_context(self.outputFormatCtx)
            
//            //TODO: might be best to never deinit and init during application start and only init once?
//            avformat_network_deinit()
            self.duration = 0
            self.closeOperation = nil
            self.operationQueue.cancelAllOperations()
            
            //Should be closed from the timer's call stack
            //avformat_close_input(&self.altFormatCtx)
            //avformat_free_context(self.altFormatCtx)
            self.setAudioOperationQueue.cancelAllOperations()
            self.probeCodecOperationQueue.cancelAllOperations()
            
            if restart {
                self.prepareToPlay()
            }
        }
        closeOperation.queuePriority = .veryHigh
        closeOperation.qualityOfService = .userInteractive
        if let readOperation {
            readOperation.cancel()
            closeOperation.addDependency(readOperation)
        } else if let openOperation {
            openOperation.cancel()
            closeOperation.addDependency(openOperation)
        }
        operationQueue.addOperation(closeOperation)
        condition.signal()
        if options.syncDecodeVideo || options.syncDecodeAudio {
            DispatchQueue.global().async { [weak self] in
                self?.allPlayerItemTracks.forEach { $0.shutdown() }
            }
        }
        self.closeOperation = closeOperation
    }
    
    func restart() {
        self.timerProbeCodec.fireDate = Date.distantFuture
        shutdown(restart: true)
    }

    func seek(time: TimeInterval, completion: @escaping ((Bool) -> Void)) {
        if state == .reading || state == .paused {
            state = .seeking
            currentPlaybackTime = time
            seekingCompletionHandler = completion
            condition.broadcast()
            allPlayerItemTracks.forEach { $0.seek(time: time) }
        } else if state == .finished {
            state = .seeking
            currentPlaybackTime = time
            seekingCompletionHandler = completion
            read()
        }
        isAudioStalled = audioTrack == nil
    }
}

extension MarblePlayerItem: MarbleCodecCapacityDelegate {
    func codecDidChangeCapacity() {
        let loadingState = options.playable(capacitys: videoAudioTracks, isFirst: isFirst, isSeek: isSeek)
        delegate?.sourceDidChange(loadingState: loadingState)
        if loadingState.isPlayable {
            isFirst = false
            isSeek = false
            if loadingState.loadedTime > options.maxBufferDuration {
                adaptableVideo(loadingState: loadingState)
                pause()
            } else if loadingState.loadedTime < options.maxBufferDuration / 2 {
                resume()
            }
        } else {
            resume()
            adaptableVideo(loadingState: loadingState)
        }
    }

    func codecDidFinished(track: some CapacityProtocol) {
        if track.mediaType == .audio {
            isAudioStalled = true
        }
        let allSatisfy = videoAudioTracks.allSatisfy { $0.isEndOfFile && $0.frameCount == 0 && $0.packetCount == 0 }
        if allSatisfy {
            delegate?.sourceDidFinished()
            timer.fireDate = Date.distantFuture
            timerProbeCodec.fireDate = Date.distantFuture
            if options.isLoopPlay {
                isAudioStalled = audioTrack == nil
                audioTrack?.isLoopModel = false
                videoTrack?.isLoopModel = false
                if state == .finished {
                    seek(time: startTime) { _ in }
                }
            }
        }
    }

    private func adaptableVideo(loadingState: LoadingState) {
        if options.videoDisable || videoAdaptation == nil || loadingState.isEndOfFile || loadingState.isSeek || state == .seeking {
            
            if loadingState.isEndOfFile {
                print("[MarblePlayerItem] adaptableVideo: eof")
            }
            return
        }
        guard let track = videoTrack else {
            return
        }
        videoAdaptation?.loadedCount = track.packetCount + track.frameCount
        videoAdaptation?.currentPlaybackTime = currentPlaybackTime
        videoAdaptation?.isPlayable = loadingState.isPlayable
        guard let (oldBitRate, newBitrate) = options.adaptable(state: videoAdaptation), oldBitRate != newBitrate,
              let newFFmpegAssetTrack = assetTracks.first(where: { $0.mediaType == .video && $0.bitRate == newBitrate })
        else {
            if loadingState.isEndOfFile {
                print("[MarblePlayerItem] adaptableVideo: newBitrate not found")
            }
            return
        }
        assetTracks.first { $0.mediaType == .video && $0.bitRate == oldBitRate }?.isEnabled = false
        newFFmpegAssetTrack.isEnabled = true
        findBestAudio(videoTrack: newFFmpegAssetTrack)
        let bitRateState = VideoAdaptationState.BitRateState(bitRate: newBitrate, time: CACurrentMediaTime())
        videoAdaptation?.bitRateStates.append(bitRateState)
        delegate?.sourceDidChange(oldBitRate: oldBitRate, newBitrate: newBitrate)
    }

    private func findBestAudio(videoTrack: FFmpegAssetTrack) {
        guard videoAdaptation != nil, let first = assetTracks.first(where: { $0.mediaType == .audio && $0.isEnabled }) else {
            return
        }
        let index = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, videoTrack.trackID, nil, 0)
        if index != first.trackID {
            first.isEnabled = false
            assetTracks.first { $0.mediaType == .audio && $0.trackID == index }?.isEnabled = true
        }
    }
}

extension MarblePlayerItem: MarblePlayerRenderSourceDelegate {
    func setVideo(time: CMTime) {
        if state == .seeking {
            return
        }
        if isAudioStalled {
            videoMediaTime = CACurrentMediaTime()
            currentPlaybackTime = time.seconds - options.audioDelay
        }
    }

    func setAudio(time: CMTime) {
        guard state != .seeking else {
            return
        }
        
        if !isAudioStalled {
            currentPlaybackTime = time.seconds
        }
    }
    
    func setAudio(time: CMTime, frame: AudioFrame) {
        guard state != .seeking else {
            return
        }
        
        guard !isAudioStalled else {
            return
        }
        
        guard let pcm = self.options.audioFormat.toPCMBuffer(frame: frame) else {
            return
        }
        
        self.delegate?.sourceDidOutputAudio(buffer: pcm)
        
        self.audioClip.update(time, buffer: pcm, format: self.options.audioFormat)
    }

    func getVideoOutputRender(force: Bool) -> VideoVTBFrame? {
        guard let videoTrack else {
            return nil
        }
        
        var desire: TimeInterval = 0
        
        let predicate: ((VideoVTBFrame) -> Bool)? = force ? nil : { [weak self] frame -> Bool in
            guard let self else { return true }
            desire = self.currentPlaybackTime + self.options.audioDelay
            #if !os(macOS)
            desire -= AVAudioSession.sharedInstance().outputLatency
            #endif
            if self.isAudioStalled {
                desire += max(CACurrentMediaTime() - self.videoMediaTime, 0)
            }
            return frame.seconds <= desire
        }
        
        let frame = videoTrack.getOutputRender(where: predicate)
        
        if let frame, !isAudioStalled {
            let type = options.videoClockSync(audioTime: desire, videoTime: frame.seconds)
            delegate?.sourceClock(type)
            switch type {
            case .drop:
                if options.dropVideoFrame {
                    return nil
                } else {
                    delegate?.sourceIsNotInSync(videoTime: frame.cmtime, audioTimeDesired: desire)
                    break
                }
            case .seek:
                videoTrack.outputRenderQueue.flush()
                videoTrack.seekTime = desire
                return nil
            case .show:
                break
            }
        }
        
        return options.videoDisable ? nil : frame
    }

    func getAudioOutputRender() -> AudioFrame? {
        return audioTrack?.getOutputRender(where: nil)
    }
    
    func getAudioBuffer() -> [AudioFrame?]? {
        return audioTrack?.outputRenderQueue.retrieve()
    }
    
    func getAudioClip() -> AudioClip? {
        return self.audioClip.copy() as? AudioClip
    }
    
    func resetAudioClip() {
        self.audioClip.reset()
    }
}
