//
//  AVAsset.swift
//  Wonder
//
//  Created by PEXAVC on 8/18/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import AVFoundation
import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import Cocoa
#endif

extension AVAsset {
    // Provide a URL for where you wish to write
    // the audio file if successful
    func writeAudioTrack(to path: String,
                         success: @escaping () -> (),
                         failure: @escaping (Error) -> ()) {
        do {
            let asset = try audioAsset()
            asset.write(to: path, success: success, failure: failure)
        } catch {
            failure(error)
        }
    }

    private func write(to path: String,
                       success: @escaping () -> (),
                       failure: @escaping (Error) -> ()) {
        path.clearFromTemp()
        
        // Create an export session that will output an
        // audio track (M4A file)
        guard let exportSession = AVAssetExportSession(asset: self,
                                                       presetName: AVAssetExportPresetAppleM4A) else {
                                                        // This is just a generic error
                                                        let error = NSError(domain: "domain",
                                                                            code: 0,
                                                                            userInfo: nil)
                                                        failure(error)

                                                        return
        }

        exportSession.outputFileType = .m4a
        exportSession.outputURL = URL(fileURLWithPath: path)

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                success()
            case .unknown, .waiting, .exporting, .failed, .cancelled:
                let error = NSError(domain: "domain", code: 0, userInfo: nil)
                failure(error)
            }
        }
    }

    private func audioAsset() throws -> AVAsset {
        // Create a new container to hold the audio track
        let composition = AVMutableComposition()
        // Create an array of audio tracks in the given asset
        // Typically, there is only one
        let audioTracks = tracks(withMediaType: .audio)

        // Iterate through the audio tracks while
        // Adding them to a new AVAsset
        for track in audioTracks {
            let compositionTrack = composition.addMutableTrack(withMediaType: .audio,
                                                               preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                // Add the current audio track at the beginning of
                // the asset for the duration of the source AVAsset
                try compositionTrack?.insertTimeRange(track.timeRange,
                                                      of: track,
                                                      at: track.timeRange.start)
            } catch {
                throw error
            }
        }

        return composition
    }
}
extension AVAsset {
    func resolutionSizeForLocalVideo() -> CGSize? {
        guard let track = self.tracks(withMediaType: AVMediaType.video).first else { return nil }
        
        return track.resolutionSizeForLocalVideo()
    }
    
    func getRotation() -> Float? {
        guard let track = self.tracks(withMediaType: AVMediaType.video).first else { return nil }
        
        return track.getRotation()
    }
    
    func save(
        toURL url: URL,
        preset: String = AVAssetExportPresetAppleM4A,
        fileType: AVFileType = .m4a, completion: @escaping ((Bool) -> Void)) {
        
        let exporter = AVAssetExportSession(asset: self, presetName: preset)
        exporter?.outputURL = url
        exporter?.outputFileType = fileType
        exporter?.shouldOptimizeForNetworkUse = true
        
        exporter?.exportAsynchronously(completionHandler: {
            switch exporter?.status {
            case AVAssetExportSession.Status.completed?:
                completion(true)
            case  AVAssetExportSession.Status.failed?:
                completion(false)
            case AVAssetExportSession.Status.cancelled?:
                completion(false)
            default:
                completion(true)
            }
            
        })
    }
    
    func thumbnail() -> MarbleImage? {
        let imgGenerator = AVAssetImageGenerator(asset: self)
        guard let cgImage = try? imgGenerator.copyCGImage(
            at: CMTime(value: 0, timescale: 1),
            actualTime: nil) else {
            return nil
        }
        
        #if os(OSX)
            return MarbleImage(
                cgImage: cgImage,
                size: self.resolutionSizeForLocalVideo() ?? .zero)
        #else
            return MarbleImage(
                cgImage: cgImage)
        #endif
    }
}

extension AVAssetTrack {
    func resolutionSizeForLocalVideo() -> CGSize {
        let size = self.naturalSize.applying(self.preferredTransform)
        
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    func getRotation() -> Float {
        return Float(atan2(self.preferredTransform.b, self.preferredTransform.a))
    }
}
