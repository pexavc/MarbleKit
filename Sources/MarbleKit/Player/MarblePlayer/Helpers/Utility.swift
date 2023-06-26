//
//  Utility.swift
//  MarbleKit
//
// https://github.com/kingslay/KSPlayer/blob/develop/Sources/KSPlayer/Core/Utility.swift
//  Created by kintan on 2018/3/9.
//

import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
#if canImport(MobileCoreServices)
import MobileCoreServices.UTType
#endif

class GIFCreator {
    private let destination: CGImageDestination
    private let frameProperties: CFDictionary
    private(set) var firstImage: MarbleImage?
    init(savePath: URL, imagesCount: Int) {
        try? FileManager.default.removeItem(at: savePath)
        frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.25]] as CFDictionary
        destination = CGImageDestinationCreateWithURL(savePath as CFURL, kUTTypeGIF, imagesCount, nil)!
        let fileProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
    }

    func add(image: CGImage) {
        if firstImage == nil {
            firstImage = MarbleImage(cgImage: image)
        }
        CGImageDestinationAddImage(destination, image, frameProperties)
    }

    func finalize() -> Bool {
        let result = CGImageDestinationFinalize(destination)
        return result
    }
}

extension String {
    static func systemClockTime(second: Bool = false) -> String {
        let date = Date()
        let calendar = Calendar.current
        let component = calendar.dateComponents([.hour, .minute, .second], from: date)
        if second {
            return String(format: "%02i:%02i:%02i", component.hour!, component.minute!, component.second!)
        } else {
            return String(format: "%02i:%02i", component.hour!, component.minute!)
        }
    }
}

extension AVAsset {
    public func generateGIF(beginTime: TimeInterval, endTime: TimeInterval, interval: Double = 0.2, savePath: URL, progress: @escaping (Double) -> Void, completion: @escaping (Error?) -> Void) {
        let count = Int(ceil((endTime - beginTime) / interval))
        let timesM = (0 ..< count).map { NSValue(time: CMTime(seconds: beginTime + Double($0) * interval)) }
        let imageGenerator = ceateImageGenerator()
        let gifCreator = GIFCreator(savePath: savePath, imagesCount: count)
        var i = 0
        imageGenerator.generateCGImagesAsynchronously(forTimes: timesM) { _, imageRef, _, result, error in
            switch result {
            case .succeeded:
                guard let imageRef else { return }
                i += 1
                gifCreator.add(image: imageRef)
                progress(Double(i) / Double(count))
                guard i == count else { return }
                if gifCreator.finalize() {
                    completion(nil)
                } else {
                    let error = NSError(domain: AVFoundationErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Generate Gif Failed!"])
                    completion(error)
                }
            case .failed:
                if let error {
                    completion(error)
                }
            case .cancelled:
                break
            @unknown default:
                break
            }
        }
    }

    private func ceateComposition(beginTime: TimeInterval, endTime: TimeInterval) async throws -> AVMutableComposition {
        let compositionM = AVMutableComposition()
        let audioTrackM = compositionM.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrackM = compositionM.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let cutRange = CMTimeRange(start: beginTime, end: endTime)
        
        #if os(xrOS)
        if let assetAudioTrack = try await loadTracks(withMediaType: .audio).first {
            try audioTrackM?.insertTimeRange(cutRange, of: assetAudioTrack, at: .zero)
        }
        if let assetVideoTrack = try await loadTracks(withMediaType: .video).first {
            try videoTrackM?.insertTimeRange(cutRange, of: assetVideoTrack, at: .zero)
        }
        #else
        if let assetAudioTrack = tracks(withMediaType: .audio).first {
            try audioTrackM?.insertTimeRange(cutRange, of: assetAudioTrack, at: .zero)
        }
        if let assetVideoTrack = tracks(withMediaType: .video).first {
            try videoTrackM?.insertTimeRange(cutRange, of: assetVideoTrack, at: .zero)
        }
        #endif
        
        return compositionM
    }

    func ceateExportSession(beginTime: TimeInterval, endTime: TimeInterval) async throws -> AVAssetExportSession? {
        let compositionM = try await ceateComposition(beginTime: beginTime, endTime: endTime)
        guard let exportSession = AVAssetExportSession(asset: compositionM, presetName: "") else {
            return nil
        }
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.outputFileType = .mp4
        return exportSession
    }

    func exportMp4(beginTime: TimeInterval, endTime: TimeInterval, outputURL: URL, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) throws {
        try FileManager.default.removeItem(at: outputURL)
//        guard let exportSession = try ceateExportSession(beginTime: beginTime, endTime: endTime) else { return }
//        exportSession.outputURL = outputURL
//        exportSession.exportAsynchronously { [weak exportSession] in
//            guard let exportSession else {
//                return
//            }
        
        Task {
            guard let exportSession = try await ceateExportSession(beginTime: beginTime, endTime: endTime) else { return }
            exportSession.outputURL = outputURL
            await exportSession.export()
            switch exportSession.status {
            case .exporting:
                progress(Double(exportSession.progress))
            case .completed:
                progress(1)
                completion(.success(outputURL))
                exportSession.cancelExport()
            case .failed:
                if let error = exportSession.error {
                    completion(.failure(error))
                }
                exportSession.cancelExport()
            case .cancelled:
                exportSession.cancelExport()
            case .unknown, .waiting:
                break
            @unknown default:
                break
            }
        }
    }

    func exportMp4(beginTime: TimeInterval, endTime: TimeInterval, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) throws {
        guard var exportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        exportURL = exportURL.appendingPathExtension("Export.mp4")
        try exportMp4(beginTime: beginTime, endTime: endTime, outputURL: exportURL, progress: progress, completion: completion)
    }
}

public extension AVAsset {
    func ceateImageGenerator() -> AVAssetImageGenerator {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        return imageGenerator
    }

    func thumbnailImage(currentTime: CMTime, handler: @escaping (MarbleImage?) -> Void) {
        let imageGenerator = ceateImageGenerator()
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: currentTime)]) { _, cgImage, _, _, _ in
            if let cgImage {
                handler(MarbleImage(cgImage: cgImage))
            } else {
                handler(nil)
            }
        }
    }
}
