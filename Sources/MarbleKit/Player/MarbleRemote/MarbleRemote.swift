//
//  MarbleRemote.swift
//  MarbleKit
//
//  Created by PEXAVC on 6/18/23.
//

import Foundation
import Combine
import AVKit
import AVFoundation
import Accelerate
import AudioToolbox
import MetalKit
import MediaPlayer
import Libavformat

public class MarbleRemote: NSObject, ObservableObject {
    public static var current: MarbleRemote = .init()
    
    public static var enableFX: Bool = false
    public static var fx: [MarbleEffect] = []
    
    public static func initializeNetwork() {
        avformat_network_init()
    }
    
    @Published var fps: Float = MarblePlayerOptions.preferredFramesPerSecond.floatValue
    @Published var selectedResolution: MarbleRemoteConfig.Resolution
    @Published private var shouldLowerResolution = false
    
    //AV
    private var audioVideoOutput: MarblePlayer?
    private var options: MarblePlayerOptions = .init()
    
    //Video
    private let config: MarbleRemoteConfig
    
    ///This is not in audioVideoOutput, since the compiled texture is available here
    private let videoClip: VideoClip = .init()
    private var subscriptions: Set<AnyCancellable> = []
    fileprivate var currentTexture: MTLTexture? = nil
    
    //FX
    public var metalContext: MetalContext = .init()
    private let marble: MarbleEngine = .init()
    private var renderer: MetalRender = .init()
    
    //TODO: ideally either MTL callback or this is sole runloop
    private lazy var displayLink: CADisplayLink? = .init(target: self, selector: #selector(render(in:)))
    
    override init() {
        self.config = .init(name: "NONE", kind: .twitch, streams: [])
        self.selectedResolution = .p1080
        super.init()
    }
    
    public init(config: MarbleRemoteConfig,
                initialResolution: MarbleRemoteConfig.Resolution = .p1080) {
        
        self.config = config
        self.selectedResolution = initialResolution
        
        super.init()
        
        MarblePlayerOptions.isUseAudioRenderer = false
        MarblePlayerOptions.firstPlayerType = MarblePlayer.self
        MarblePlayerOptions.secondPlayerType = MarblePlayer.self
        MarblePlayerOptions.logLevel = .info//.debug
        
        self.options = .init()
        
        $shouldLowerResolution
            .dropFirst()
            .filter({ $0 == true })
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                self.lowerResolutionIfPossible()
            })
            .store(in: &subscriptions)
        
        $selectedResolution
            .sink(receiveValue: { [weak self] resolution in
                guard let self = self else { return }
                self.replaceItem(with: resolution)
            })
            .store(in: &subscriptions)
    }
    
    deinit {
        shutdown()
    }
    
    private func lowerResolutionIfPossible() {
        guard let newResolution = MarbleRemoteConfig.Resolution(rawValue: selectedResolution.rawValue - 1) else { return }
        selectedResolution = newResolution
    }
    
    private func replaceItem(with newResolution: MarbleRemoteConfig.Resolution) {
        guard let stream = self.config.streams.first(where: { $0.resolution == newResolution }) else { return }
        
        self.setupAudioVideo(url: stream.streamURL)
        
        print("[MarbleRemote] added video & audio")
        
        self.displayLink?.add(to: .main, forMode: .common)
        
        self.audioVideoOutput?.play()
    }
}

//MARK: Audio Setup
extension MarbleRemote {
    func setupAudioVideo(url: URL, delay: Double = 0.0) {
        options.audioDelay = delay
        options.syncDecodeAudio = false
        options.syncDecodeVideo = false
        //options.cache = true
        //options.maxAnalyzeDuration = Int64(MarblePlayerOptions.maxBufferDuration)
        
        let player: MarblePlayer = .init(url: url, options: options)
        
        self.audioVideoOutput = player
        self.audioVideoOutput?.delegate = self
        self.audioVideoOutput?.prepareToPlay()
    }
}

//MARK: MarblePlayerDelegate
extension MarbleRemote: MarblePlayerDelegate {
    public func readyToPlay(player: some MarblePlayerProtocol) {
        self.fps = self.audioVideoOutput?.fps ?? 60
        displayLink?.preferredFramesPerSecond = Int(ceil(self.fps)) << 1
        
        //TODO: isLiveStream should be a getter from remoteConfig
        let metadata = MarbleNowPlayableMetadata(mediaType: .video,
                                                 isLiveStream: true,
                                                 title: config.description,
                                                 artist: config.name)
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = metadata.nowPlayingInfo
    }
    
    public func changeLoadState(player: some MarblePlayerProtocol, loadState: MarbleMediaLoadState) {
        BufferingProgress.shared.update(loadState: loadState)
    }
    
    public func changeBuffering(player: some MarblePlayerProtocol,
                                progress: Int) {
        BufferingProgress.shared.update(progress: progress)
    }
    
    public func playBack(player: some MarblePlayerProtocol, loopCount: Int) {
        switch player.playbackState {
        case .playing:
            MPNowPlayingInfoCenter.default().playbackState = .playing
        case .paused:
            MPNowPlayingInfoCenter.default().playbackState = .paused
        default:
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }
    
    public func finish(player: some MarblePlayerProtocol, error: Error?) {
        
    }
    
    public func clockProcessChanged(_ type: ClockProcessType) {
        BufferingProgress.shared.update(clockType: type)
        
        //TODO: detect frame drop, restart, if not restarting
//        DispatchQueue.main.async { [weak self] in
//            if type == .drop {
//                self?.audioVideoOutput?.restart(playerItemOnly: true)
//            }
//        }
    }
    
    public func fpsChanged(_ fps: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.fps = fps
            self?.displayLink?.preferredFramesPerSecond = Int(ceil(self?.fps ?? MarblePlayerOptions.preferredFramesPerSecond.floatValue)) << 1
        }
    }
}

//MARK: Marble MetalViewDelegate + Rendering
extension MarbleRemote: MetalViewUIDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    public func draw(in view: MTKView) {
        autoreleasepool {
            guard audioVideoOutput?.loadState == .playable else {
                
                if let drawable = view.currentDrawable {
                    self.clear(drawable)
                }
                
                return
            }
            
            //TODO: call render() directly if DisplayLink is not being used
            guard let inputTexture = self.currentTexture else {//render() else {
                return
            }
            
            let commandQueue = metalContext.commandQueue
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let drawable = view.currentDrawable else {
                return
            }
            
            metalContext.kernels.downsample.encode(
                commandBuffer: commandBuffer,
                inputTexture: inputTexture,
                outputTexture: drawable.texture)

            commandBuffer.addScheduledHandler { [weak self] (buffer) in
                guard let unwrappedSelf = self else { return }
            }

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    func clear(_ drawable: CAMetalDrawable) {
        renderer.clear(drawable: drawable)
    }
    
    
    @objc func render(in _: Any) {
        autoreleasepool {
            self.currentTexture = render()
        }
    }
    
    func render() -> MTLTexture? {
        guard audioVideoOutput?.loadState == .playable,
              //This will pop the render queue's circular buffer
              //Potentially can get out of sync
              //if video is pulling faster or slower than
              //audios'
              let videoFrame = audioVideoOutput?.getVideoFrame(),
              let buffer = videoFrame.corePixelBuffer else {
            return nil
        }
        
        audioVideoOutput?.setVideo(time: videoFrame.cmtime)
        
        guard let texture = prepare(buffer) else {
            return nil
        }
        
        let inputTexture = renderFX(texture)
        
        self.videoClip.update(videoFrame.cmtime,
                              fps: fps,
                              buffer: buffer,
                              texture: inputTexture)
        
        return inputTexture
    }
    
    func prepare(_ buffer: CVPixelBuffer) -> MTLTexture? {
        let descriptor: MTLTextureDescriptor = MTLTextureDescriptor
            .texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                 width: buffer.width,
                                 height: buffer.height,
                                 mipmapped: false)
        
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        let context = self.metalContext
        
        guard let texture = context.device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        renderer.draw(pixelBuffer: buffer, display: options.display, texture: texture)
        
        return texture
    }
    
    func renderFX(_ texture: MTLTexture) -> MTLTexture {
        guard MarbleRemote.enableFX,
              MarbleRemote.fx.isEmpty == false else {
            return texture
        }
        
        //Audio Analyzed
        let audioSample = audioVideoOutput?.getLastAudioSample() ?? .init()

        guard audioSample.isReady else {
            return texture
        }
        
        let context = self.metalContext
        
        let layers: [MarbleLayer] = MarbleRemote.fx.map {
            .init($0.getLayer(audioSample.amplitude, threshold: 1.0))
        }
        
        let composite: MarbleComposite = .init(
            resource: .init(
                textures: .init(main: texture),
                size: texture.size),
            layers: layers)

        let compiled = marble.compile(
            fromContext: context,
            forComposite: composite)

        if let filteredTexture = compiled.resource?.textures?.main {
            return filteredTexture
        } else {
            return texture
        }
    }
}

//MARK: Public extensions
public extension MarbleRemote {
    func play() {
        audioVideoOutput?.play()
        displayLink?.isPaused = false
    }
    
    func pause() {
        audioVideoOutput?.pause()
        displayLink?.isPaused = true
    }
    
    func shutdown() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        displayLink?.invalidate()
        displayLink = nil
        
        audioVideoOutput?.shutdown()
        BufferingProgress.shared.reset()
        
        clearClipCache()
    }
    
    func clearClipCache() {
        self.videoClip.reset()
        self.audioVideoOutput?.resetAudioClip()
        Clip.shared.reset()
    }
    
    var currentPlaybackTime: TimeInterval? {
        self.audioVideoOutput?.currentPlaybackTime
    }
    
    func clip() {
        guard let videoClip = self.videoClip.copy() as? VideoClip,
              let audioClip = self.audioVideoOutput?.getAudioClip() else {
            return
        }

        Clip.shared.render(video: videoClip, audio: audioClip)
    }
    
    var isMuted: Bool {
        get {
            self.audioVideoOutput?.isMuted ?? false
        }
        set {
            self.audioVideoOutput?.isMuted = newValue
        }
    }
    
    var volume: Float {
        get {
            self.audioVideoOutput?.playbackVolume ?? 0.5
        }
        set {
            self.audioVideoOutput?.playbackVolume = newValue
        }
    }
    
    func fireMarblePlayerItemDebug() {
        self.audioVideoOutput?.firePlayerItemDebug()
    }
}

//MARK: -- DisplayLink

#if os(macOS)
import CoreVideo
class CADisplayLink {
    private let displayLink: CVDisplayLink
    private var target: AnyObject?
    private let selector: Selector
    private var runloop: RunLoop?
    private var mode = RunLoop.Mode.default
    public var preferredFramesPerSecond = 60
    public var timestamp: TimeInterval {
        var timeStamp = CVTimeStamp()
        if CVDisplayLinkGetCurrentTime(displayLink, &timeStamp) == kCVReturnSuccess, (timeStamp.flags & CVTimeStampFlags.hostTimeValid.rawValue) != 0 {
            return TimeInterval(timeStamp.hostTime / NSEC_PER_SEC)
        }
        return 0
    }

    public var duration: TimeInterval {
        CVDisplayLinkGetActualOutputVideoRefreshPeriod(displayLink)
    }

    public var targetTimestamp: TimeInterval {
        duration + timestamp
    }

    public var isPaused: Bool {
        get {
            !CVDisplayLinkIsRunning(displayLink)
        }
        set {
            if newValue {
                CVDisplayLinkStop(displayLink)
            } else {
                CVDisplayLinkStart(displayLink)
            }
        }
    }

    public init(target: NSObject, selector sel: Selector) {
        self.target = target
        selector = sel
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink)
        self.displayLink = displayLink!
        CVDisplayLinkSetOutputCallback(self.displayLink, { (_, _, _, _, _, userData: UnsafeMutableRawPointer?) -> CVReturn in
            guard let userData else {
                return kCVReturnError
            }
            let `self` = Unmanaged<CADisplayLink>.fromOpaque(userData).takeUnretainedValue()
            guard let runloop = self.runloop, let target = self.target else {
                return kCVReturnSuccess
            }
            runloop.perform(self.selector, target: target, argument: self, order: 0, modes: [self.mode])
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(self.displayLink)
    }

    open func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        self.runloop = runloop
        self.mode = mode
    }

    public func invalidate() {
        isPaused = true
        runloop = nil
        target = nil
    }
}
#endif
