//
//  MarblePlayer.swift
//  MarbleKit.Player
//
//  Created by PEXAVC on 6/18/23.
//

import AVFoundation
import AVKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public class MarblePlayer: NSObject {
    private var loopCount = 1
    private var playerItem: MarblePlayerItem
    private let audioOutput: AudioPlayer & MarblePlayerFrameOutput = MarblePlayerOptions.isUseAudioRenderer ? AudioRendererPlayer() : AudioEnginePlayer()
    
    private var options: MarblePlayerOptions
    private var bufferingCountDownTimer: Timer?
    
    public private(set) var playableTime = TimeInterval(0)
    public private(set) var isReadyToPlay = false
    public var allowsExternalPlayback: Bool = false
    public var usesExternalPlaybackWhileExternalScreenIsActive: Bool = false
    
    private var lastAudioSample: AudioSample = .shared
    
    public var fps: Float = 60
    
    public weak var delegate: MarblePlayerDelegate?
    
    public private(set) var bufferingProgress = 0 {
        didSet {
            delegate?.changeBuffering(player: self, progress: bufferingProgress)
        }
    }

    public var playbackRate: Float = 1 {
        didSet {
            audioOutput.playbackRate = playbackRate
        }
    }

    public private(set) var loadState = MarbleMediaLoadState.idle {
        didSet {
            if loadState != oldValue {
                playOrPause()
            }
        }
    }

    public private(set) var playbackState = MarbleMediaPlaybackState.idle {
        didSet {
            if playbackState != oldValue {
                playOrPause()
                if playbackState == .finished {
                    delegate?.finish(player: self, error: nil)
                }
            }
        }
    }

    public required init(url: URL, options: MarblePlayerOptions) {
        playerItem = MarblePlayerItem(url: url, options: options)
        
        self.options = options
        super.init()
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
        
        
        #if !os(macOS)
        if #available(tvOS 15.0, iOS 15.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(spatialCapabilityChange), name: AVAudioSession.spatialPlaybackCapabilitiesChangedNotification, object: nil)
        }
        #endif
    }

    deinit {
        playerItem.shutdown()
    }
}

// MARK: - private functions

private extension MarblePlayer {
    func playOrPause() {
        runInMainqueue { [weak self] in
            guard let self else { return }
            let isPaused = !(self.playbackState == .playing && self.loadState == .playable)
            if isPaused {
                self.audioOutput.pause()
            } else {
                self.audioOutput.play(time: self.playerItem.currentPlaybackTime)
            }
            self.delegate?.changeLoadState(player: self)
        }
    }

    @objc private func spatialCapabilityChange(notification _: Notification) {
        let audioDescriptor = tracks(mediaType: .audio).first { $0.isEnabled }.flatMap {
            $0 as? FFmpegAssetTrack
        }?.audioDescriptor ?? .defaultValue
        options.setAudioSession(audioDescriptor: audioDescriptor)
    }
}

extension MarblePlayer: MarblePlayerSourceDelegate {
    func sourceDidOpened() {
        isReadyToPlay = true
        options.readyTime = CACurrentMediaTime()
        let audioDescriptor = tracks(mediaType: .audio).first { $0.isEnabled }.flatMap {
            $0 as? FFmpegAssetTrack
        }?.audioDescriptor ?? .defaultValue
        options.setAudioSession(audioDescriptor: audioDescriptor)
        audioOutput.prepare(audioFormat: options.audioFormat)
        let fps = tracks(mediaType: .video).first { $0.isEnabled }.map(\.nominalFrameRate) ?? 24
        
        self.fps = fps
        self.lastAudioSample.load(options.audioFrameMaxCount(fps: fps, channels: Int(audioDescriptor.channels)))
        
        runInMainqueue { [weak self] in
            guard let self else { return }
            
            self.delegate?.readyToPlay(player: self)
        }
    }

    func sourceDidFailed(error: NSError?) {
        runInMainqueue { [weak self] in
            guard let self else { return }
            self.delegate?.finish(player: self, error: error)
        }
    }

    func sourceDidFinished() {
        runInMainqueue { [weak self] in
            guard let self else { return }
            if self.options.isLoopPlay {
                self.loopCount += 1
                self.delegate?.playBack(player: self, loopCount: self.loopCount)
                self.audioOutput.play(time: 0)
                
            } else {
                self.playbackState = .finished
            }
        }
    }

    func sourceDidChange(loadingState: LoadingState) {
        if loadingState.isEndOfFile {
            playableTime = duration
        } else {
            playableTime = currentPlaybackTime + loadingState.loadedTime
        }
        if loadState == .playable {
            if !loadingState.isEndOfFile, loadingState.frameCount == 0, loadingState.packetCount == 0 || !(loadingState.isFirst || loadingState.isSeek) {
                loadState = .loading
                if playbackState == .playing {
                    runInMainqueue { [weak self] in
                        self?.bufferingProgress = 0
                    }
                }
            }
        } else {
            var progress = 100
            if loadingState.isPlayable {
                loadState = .playable
            } else {
                if loadingState.progress.isInfinite {
                    progress = 100
                } else if loadingState.progress.isNaN {
                    progress = 0
                } else {
                    progress = min(100, Int(loadingState.progress))
                }
            }
            if playbackState == .playing {
                runInMainqueue { [weak self] in
                    self?.bufferingProgress = progress
                }
            }
        }
    }

    func sourceDidChange(oldBitRate: Int64, newBitrate: Int64) {
        MarblePlayerLog("oldBitRate \(oldBitRate) change to newBitrate \(newBitrate)")
    }
    
    func sourceDidOutputAudio(buffer: AVAudioPCMBuffer?) {
        self.lastAudioSample.update(buffer)
    }
}

extension MarblePlayer: MarblePlayerProtocol {
    public var playbackVolume: Float {
        get {
            audioOutput.volume
        }
        set {
            audioOutput.volume = newValue
        }
    }

    public var isPlaying: Bool { playbackState == .playing }

    public var naturalSize: CGSize {
        options.display == .plane ? playerItem.naturalSize : MarblePlayerOptions.sceneSize
    }

    public var isExternalPlaybackActive: Bool { false }

    public func replace(url: URL, options: MarblePlayerOptions) {
        MarblePlayerLog("replaceUrl \(self)")
        shutdown()
        playerItem.delegate = nil
        playerItem = MarblePlayerItem(url: url, options: options)
        self.options = options
        playerItem.delegate = self
        audioOutput.renderSource = playerItem
    }

    public var currentPlaybackTime: TimeInterval {
        get {
            playerItem.currentPlaybackTime - playerItem.startTime
        }
        set {
            seek(time: newValue) { _ in }
        }
    }

    public var duration: TimeInterval { playerItem.duration }

    public var seekable: Bool { playerItem.seekable }

    public func seek(time: TimeInterval, completion: @escaping ((Bool) -> Void)) {
        let time = max(time, 0)
        playbackState = .seeking
        runInMainqueue { [weak self] in
            self?.bufferingProgress = 0
        }
        let seekTime: TimeInterval
        if time >= duration, options.isLoopPlay {
            seekTime = 0
        } else {
            seekTime = time
        }
        audioOutput.flush()
        playerItem.seek(time: seekTime + playerItem.startTime, completion: completion)
    }

    public func prepareToPlay() {
        MarblePlayerLog("prepareToPlay \(self)")
        options.prepareTime = CACurrentMediaTime()
        playerItem.prepareToPlay()
        bufferingProgress = 0
    }

    public func play() {
        MarblePlayerLog("play \(self)")
        playbackState = .playing
    }

    public func pause() {
        MarblePlayerLog("pause \(self)")
        playbackState = .paused
    }

    public func shutdown() {
        MarblePlayerLog("shutdown \(self)")
        playbackState = .stopped
        loadState = .idle
        isReadyToPlay = false
        loopCount = 0
        lastAudioSample = .init()
        playerItem.shutdown()
        options.prepareTime = 0
        options.dnsStartTime = 0
        options.tcpStartTime = 0
        options.tcpConnectedTime = 0
        options.openTime = 0
        options.findTime = 0
        options.readyTime = 0
        options.readAudioTime = 0
        options.readVideoTime = 0
        options.decodeAudioTime = 0
        options.decodeVideoTime = 0
    }

    public func enterBackground() {}

    public func enterForeground() {}

    public var isMuted: Bool {
        get {
            audioOutput.isMuted
        }
        set {
            audioOutput.isMuted = newValue
        }
    }

    public func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack] {
        playerItem.assetTracks.compactMap { track -> MediaPlayerTrack? in
            if track.mediaType == mediaType {
                return track
            } else if mediaType == .subtitle {
                return track.closedCaptionsTrack
            }
            return nil
        }
    }

    public func select(track: MediaPlayerTrack) {
        if track.mediaType == .video {
            let fps = tracks(mediaType: .video).first { $0.isEnabled }.map(\.nominalFrameRate) ?? 24
            self.fps = fps
        }
        if track.mediaType == .audio {
            let audioDescriptor = tracks(mediaType: .audio).first { $0.isEnabled }.flatMap {
                $0 as? FFmpegAssetTrack
            }?.audioDescriptor ?? .defaultValue
            if let assetTrack = track as? FFmpegAssetTrack, assetTrack.audioDescriptor != audioDescriptor {
                options.setAudioSession(audioDescriptor: audioDescriptor)
                audioOutput.prepare(audioFormat: options.audioFormat)
            }
        }
        playerItem.select(track: track)
    }
}

// MARK: - public functions

public extension MarblePlayer {
    var metadata: [String: String] {
        playerItem.metadata
    }

    var bytesRead: Int64 {
        playerItem.bytesRead
    }

    var attackTime: Float {
        get {
            audioOutput.attackTime
        }
        set {
            audioOutput.attackTime = newValue
        }
    }

    var releaseTime: Float {
        get {
            audioOutput.releaseTime
        }
        set {
            audioOutput.releaseTime = newValue
        }
    }

    var threshold: Float {
        get {
            audioOutput.threshold
        }
        set {
            audioOutput.threshold = newValue
        }
    }

    var expansionRatio: Float {
        get {
            audioOutput.expansionRatio
        }
        set {
            audioOutput.expansionRatio = newValue
        }
    }

    var overallGain: Float {
        get {
            audioOutput.overallGain
        }
        set {
            audioOutput.overallGain = newValue
        }
    }
    
    func getLastAudioSample() -> AudioSample {
        return lastAudioSample
    }
    
    func getVideoFrame() -> VideoVTBFrame? {
        return playerItem.getVideoOutputRender(force: false)
    }
    
    func getAudioClip() -> AudioClip? {
        return playerItem.getAudioClip()
    }
    
    func resetAudioClip() {
        playerItem.resetAudioClip()
    }
}
