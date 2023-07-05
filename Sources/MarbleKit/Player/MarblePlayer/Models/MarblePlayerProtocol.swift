//
//  MarblePlayerProtocol.swift
//  MarbleKit
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public protocol MarbleMediaPlayback: AnyObject {
    var duration: TimeInterval { get }
    var naturalSize: CGSize { get }
    var currentPlaybackTime: TimeInterval { get }
    func prepareToPlay()
    func shutdown(restart: Bool)
    func seek(time: TimeInterval, completion: @escaping ((Bool) -> Void))
}

public extension MarbleMediaPlayback {
    func shutdown() {
        self.shutdown(restart: false)
    }
}

public protocol MarblePlayerProtocol: MarbleMediaPlayback {
    var delegate: MarblePlayerDelegate? { get set }
    var playableTime: TimeInterval { get }
    var isReadyToPlay: Bool { get }
    var playbackState: MarbleMediaPlaybackState { get }
    var loadState: MarbleMediaLoadState { get }
    var isPlaying: Bool { get }
    var seekable: Bool { get }
    //    var numberOfBytesTransferred: Int64 { get }
    var isMuted: Bool { get set }
    var allowsExternalPlayback: Bool { get set }
    var usesExternalPlaybackWhileExternalScreenIsActive: Bool { get set }
    var isExternalPlaybackActive: Bool { get }
    var playbackRate: Float { get set }
    var playbackVolume: Float { get set }
    @available(tvOS 14.0, *)
    init(url: URL, options: MarblePlayerOptions)
    func replace(url: URL, options: MarblePlayerOptions)
    func play()
    func pause()
    func enterBackground()
    func enterForeground()
    func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack]
    func select(track: MediaPlayerTrack)
}

public extension MarblePlayerProtocol {
    var nominalFrameRate: Float {
        tracks(mediaType: .video).first { $0.isEnabled }?.nominalFrameRate ?? 0
    }
}

public protocol MarblePlayerDelegate: AnyObject {
    func readyToPlay(player: some MarblePlayerProtocol)
    func changeLoadState(player: some MarblePlayerProtocol, loadState: MarbleMediaLoadState)
    func clockProcessChanged(_ type: ClockProcessType)
    func fpsChanged(_ fps: Float)
    // 0-100
    func changeBuffering(player: some MarblePlayerProtocol, progress: Int)
    func playBack(player: some MarblePlayerProtocol, loopCount: Int)
    func finish(player: some MarblePlayerProtocol, error: Error?)
}

public protocol MediaPlayerTrack: AnyObject, CustomStringConvertible {
    var trackID: Int32 { get }
    var name: String { get }
    var language: String? { get }
    var mediaType: AVFoundation.AVMediaType { get }
    var mediaSubType: CMFormatDescription.MediaSubType { get }
    var nominalFrameRate: Float { get }
    var rotation: Int16 { get }
    var bitRate: Int64 { get }
    var naturalSize: CGSize { get }
    var isEnabled: Bool { get set }
    var depth: Int32 { get }
    var fullRangeVideo: Bool { get }
    var colorPrimaries: String? { get }
    var transferFunction: String? { get }
    var yCbCrMatrix: String? { get }
    var isImageSubtitle: Bool { get }
    var audioStreamBasicDescription: AudioStreamBasicDescription? { get }
    var dovi: DOVIDecoderConfigurationRecord? { get }
    var fieldOrder: FFmpegFieldOrder { get }
}

public enum MarbleMediaPlaybackState: Int {
    case idle
    case playing
    case paused
    case seeking
    case finished
    case stopped
}

public enum MarbleMediaLoadState: Int {
    case idle
    case loading
    case playable
}

// swiftlint:disable identifier_name
public struct DOVIDecoderConfigurationRecord {
    let dv_version_major: UInt8
    let dv_version_minor: UInt8
    let dv_profile: UInt8
    let dv_level: UInt8
    let rpu_present_flag: UInt8
    let el_present_flag: UInt8
    let bl_present_flag: UInt8
    let dv_bl_signal_compatibility_id: UInt8
}

public enum FFmpegFieldOrder: UInt8 {
    case unknown = 0
    case progressive
    case tt // < Top coded_first, top displayed first
    case bb // < Bottom coded first, bottom displayed first
    case tb // < Top coded first, bottom displayed first
    case bt // < Bottom coded first, top displayed first
}
// swiftlint:enable identifier_name

public protocol AudioRemoteProtocol: MarbleMediaPlayback {
    var delegate: MarblePlayerDelegate? { get set }
    var playableTime: TimeInterval { get }
    var isReadyToPlay: Bool { get }
    var playbackState: MarbleMediaPlaybackState { get }
    var loadState: MarbleMediaLoadState { get }
    var isPlaying: Bool { get }
    var seekable: Bool { get }
    var isMuted: Bool { get set }
    var allowsExternalPlayback: Bool { get set }
    var usesExternalPlaybackWhileExternalScreenIsActive: Bool { get set }
    var isExternalPlaybackActive: Bool { get }
    var playbackRate: Float { get set }
    var playbackVolume: Float { get set }
    init(url: URL, options: MarblePlayerOptions)
    func replace(url: URL, options: MarblePlayerOptions)
    func play()
    func pause()
    func enterBackground()
    func enterForeground()
    func tracks(mediaType: AVFoundation.AVMediaType) -> [MediaPlayerTrack]
    func select(track: MediaPlayerTrack)
}
