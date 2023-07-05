//
//  MarblePlayerItem.Reading.swift
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
    func reading() {
        let packet = Packet()
        guard let corePacket = packet.corePacket else {
            return
        }
        let readResult = av_read_frame(formatCtx, corePacket)
        if state == .closed {
            return
        }
        if readResult == 0 {
            if let outputFormatCtx, let formatCtx {
                let index = Int(corePacket.pointee.stream_index)
                if let outputIndex = streamMapping[index],
                   let inputTb = formatCtx.pointee.streams[index]?.pointee.time_base,
                   let outputTb = outputFormatCtx.pointee.streams[outputIndex]?.pointee.time_base
                {
                    av_packet_ref(outputPacket, corePacket)
                    outputPacket?.pointee.stream_index = Int32(outputIndex)
                    av_packet_rescale_ts(outputPacket, inputTb, outputTb)
                    outputPacket?.pointee.pos = -1
                    let ret = av_interleaved_write_frame(outputFormatCtx, outputPacket)
                    if ret < 0 {
                        MarblePlayerLog("can not av_interleaved_write_frame")
                    }
                }
            }
            if formatCtx?.pointee.pb?.pointee.eof_reached == 1 {
                //TODO: need reconnect
            }
            if corePacket.pointee.size <= 0 {
                return
            }
            packet.fill()
            let first = assetTracks.first { $0.trackID == corePacket.pointee.stream_index }
            if let first, first.isEnabled {
                packet.assetTrack = first
                if first.mediaType == .video {
                    
//                    //Handle new framerate if any
//                    //TODO: make re-usable see FFmpegAssetTrack l:53
//                    if let stream = formatCtx?.pointee.streams[Int(corePacket.pointee.stream_index)] {
//                        var timebase = Timebase(corePacket.pointee.time_base)
//                        if timebase.num <= 0 || timebase.den <= 0 {
//                            timebase = Timebase(num: 1, den: 1000)
//                        }
//                        
//                        let frameRate = stream.pointee.avg_frame_rate
//                        var nominalFrameRate: Float = 0
//                        if stream.pointee.duration > 0, stream.pointee.nb_frames > 0, stream.pointee.nb_frames != stream.pointee.duration {
//                            nominalFrameRate = Float(stream.pointee.nb_frames) * Float(timebase.den) / Float(stream.pointee.duration) * Float(timebase.num)
//                        } else if frameRate.den > 0, frameRate.num > 0 {
//                            nominalFrameRate = Float(frameRate.num) / Float(frameRate.den)
//                        }
//                        if videoTrack?.fps != nominalFrameRate && nominalFrameRate > .zero {
//                            print("[MarblePlayerItem] newFPS: \(nominalFrameRate)")
//                            delegate?.packetReceivedFPS(nominalFrameRate)
//                        }
//                    }
                    
                    if options.readVideoTime == 0 {
                        options.readVideoTime = CACurrentMediaTime()
                    }
                    videoTrack?.putPacket(packet: packet)
                } else if first.mediaType == .audio {
                    if options.readAudioTime == 0 {
                        options.readAudioTime = CACurrentMediaTime()
                    }
                    audioTrack?.putPacket(packet: packet)
                } else {
                    first.subtitle?.putPacket(packet: packet)
                }
            }
        } else {
            if readResult == AVError.eof.code || formatCtx?.pointee.pb?.pointee.eof_reached == 1 {
                if options.isLoopPlay, allPlayerItemTracks.allSatisfy({ !$0.isLoopModel }) {
                    allPlayerItemTracks.forEach { $0.isLoopModel = true }
                    _ = av_seek_frame(formatCtx, -1, Int64(startTime), AVSEEK_FLAG_BACKWARD)
                } else {
                    allPlayerItemTracks.forEach { $0.isEndOfFile = true }
                    state = .finished
                }
            } else {
                //                        if IS_AVERROR_INVALIDDATA(readResult)
                error = .init(errorCode: .readFrame, avErrorCode: readResult)
            }
        }
    }
}
