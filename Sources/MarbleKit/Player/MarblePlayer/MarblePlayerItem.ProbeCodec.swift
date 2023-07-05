//
//  MarblePlayerItem.CodeChange.swift
//
//
//  Created by PEXAVC on 7/4/23.
//

import AVFoundation
import FFmpegKit
import Libavcodec
import Libavfilter
import Libavformat

internal extension MarblePlayerItem {
    func probeCodec() {
        print("[MarblePlayer] Probe Codec")
        avformat_close_input(&self.altFormatCtx)
        altFormatCtx = avformat_alloc_context()
        guard let altFormatCtx else {
            return
        }
        
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
        
        var result = avformat_open_input(&self.altFormatCtx, urlString, nil, &avOptions)
        av_dict_free(&avOptions)
        
        guard result == 0 else {
            return
        }
        
        result = avformat_find_stream_info(altFormatCtx, nil)
        
        let fps: Float = assetTracks.first { $0.mediaType == .video }?.nominalFrameRate ?? Float(MarblePlayerOptions.preferredFramesPerSecond)
        var foundFPS: Float = fps
        for i in 0..<Int(altFormatCtx.pointee.nb_streams) {
            if let coreStream = altFormatCtx.pointee.streams[i] {
                coreStream.pointee.discard = AVDISCARD_ALL
                if let assetTrack = FFmpegAssetTrack(stream: coreStream),
                   assetTrack.mediaType == .video {
                    
                    foundFPS = assetTrack.nominalFrameRate
                    
                    //TODO: handle multiple video streams in the future
                    break
                }
            }
        }
        
        avformat_close_input(&self.altFormatCtx)
        
        guard fps != foundFPS,
              lastProbedFPS != foundFPS else {
            return
        }
        
        print("[MarblePlayer] FPS Changed after Probing Codec, \(fps) != \(foundFPS), state: \(state)")
        
//        guard let formatCtx else { return }
        
//        pause()
//
//        //openThread()
//        createCodec(formatCtx: formatCtx)
//        if videoTrack == nil, audioTrack == nil {
//            state = .failed
//        } else {
//            resume()
//        }
        
        self.restart()
        
        self.lastProbedFPS = foundFPS
        delegate?.probedCodecReceivedFPS(foundFPS)
    }
}

extension MarblePlayerItem {
    func fireItemDebug() {
        self.restart()
    }
}
