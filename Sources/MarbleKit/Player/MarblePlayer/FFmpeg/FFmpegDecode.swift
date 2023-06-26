//
//  FFmpegDecode.swift
//  MarbleKit.Player
//
//  Based on: https://github.com/kingslay/KSPlayer/blob/develop/Sources/KSPlayer/MEPlayer/FFmpegDecode.swift
//  Created by kintan on 2018/3/9.
//

import AVFoundation
import Foundation
import Libavcodec

class FFmpegDecode: DecodeProtocol {
    private let options: MarblePlayerOptions
    // Do not call avcodec_flush_buffers on the first seek. Otherwise, after the seek, a blue screen may occur due to the frame not being a key frame.
    private var firstSeek = true
    private var coreFrame: UnsafeMutablePointer<AVFrame>? = av_frame_alloc()
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private var bestEffortTimestamp = Int64(0)
    private let swresample: Swresample
    private let filter: MarblePlayerFilter
    required init(assetTrack: FFmpegAssetTrack, options: MarblePlayerOptions) {
        self.options = options
        do {
            codecContext = try assetTrack.ceateContext(options: options)
        } catch {
            MarblePlayerLog(error as CustomStringConvertible)
        }
        codecContext?.pointee.time_base = assetTrack.timebase.rational
        filter = MarblePlayerFilter(timebase: assetTrack.timebase, isAudio: assetTrack.mediaType == .audio, nominalFrameRate: assetTrack.nominalFrameRate, options: options)
        if assetTrack.mediaType == .video {
            swresample = VideoSwresample()
        } else {
            swresample = AudioSwresample(audioDescriptor: assetTrack.audioDescriptor, audioFormat: options.audioFormat)
        }
    }

    func decodeFrame(from packet: Packet, completionHandler: @escaping (Result<MarblePlayerFrame, Error>) -> Void) {
        guard let codecContext, avcodec_send_packet(codecContext, packet.corePacket) == 0 else {
            return
        }
        while true {
            let result = avcodec_receive_frame(codecContext, coreFrame)
            if result == 0, let avframe = coreFrame {
                do {
                    var frame = try swresample.transfer(avframe: filter.filter(options: options, inputFrame: avframe, hwFramesCtx: codecContext.pointee.hw_frames_ctx))

                    frame.timebase = packet.assetTrack.timebase
//                frame.timebase = Timebase(avframe.pointee.time_base)
                    frame.size = avframe.pointee.pkt_size
                    frame.duration = avframe.pointee.duration
                    if frame.duration == 0, avframe.pointee.sample_rate != 0, frame.timebase.num != 0 {
                        frame.duration = Int64(avframe.pointee.nb_samples) * Int64(frame.timebase.den) / (Int64(avframe.pointee.sample_rate) * Int64(frame.timebase.num))
                    }
                    if packet.assetTrack.mediaType == .video {
                        if Int32(codecContext.pointee.properties) & FF_CODEC_PROPERTY_CLOSED_CAPTIONS > 0, packet.assetTrack.closedCaptionsTrack == nil {
                            var codecpar = AVCodecParameters()
                            codecpar.codec_type = AVMEDIA_TYPE_SUBTITLE
                            codecpar.codec_id = AV_CODEC_ID_EIA_608
                            if let assetTrack = FFmpegAssetTrack(codecpar: codecpar) {
                                assetTrack.name = "Closed Captions"
                                assetTrack.startTime = packet.assetTrack.startTime
                                assetTrack.timebase = packet.assetTrack.timebase
                                let subtitle = SyncPlayerItemTrack<SubtitleFrame>(assetTrack: assetTrack, options: options)
                                assetTrack.isEnabled = !assetTrack.isImageSubtitle
                                assetTrack.subtitle = subtitle
                                packet.assetTrack.closedCaptionsTrack = assetTrack
                                subtitle.decode()
                            }
                        }
                        if let sideData = av_frame_get_side_data(avframe, AV_FRAME_DATA_A53_CC),
                           let closedCaptionsTrack = packet.assetTrack.closedCaptionsTrack,
                           let subtitle = closedCaptionsTrack.subtitle
                        {
                            let closedCaptionsPacket = Packet()
                            closedCaptionsPacket.assetTrack = closedCaptionsTrack
                            if let corePacket = packet.corePacket {
                                closedCaptionsPacket.corePacket?.pointee.pts = corePacket.pointee.pts
                                closedCaptionsPacket.corePacket?.pointee.dts = corePacket.pointee.dts
                                closedCaptionsPacket.corePacket?.pointee.pos = corePacket.pointee.pos
                                closedCaptionsPacket.corePacket?.pointee.time_base = corePacket.pointee.time_base
                                closedCaptionsPacket.corePacket?.pointee.stream_index = corePacket.pointee.stream_index
                            }
                            closedCaptionsPacket.corePacket?.pointee.flags |= AV_PKT_FLAG_KEY
                            closedCaptionsPacket.corePacket?.pointee.size = Int32(sideData.pointee.size)
                            let buffer = av_buffer_ref(sideData.pointee.buf)
                            closedCaptionsPacket.corePacket?.pointee.data = buffer?.pointee.data
                            closedCaptionsPacket.corePacket?.pointee.buf = buffer
                            closedCaptionsPacket.fill()
                            subtitle.putPacket(packet: closedCaptionsPacket)
                        }
                        if let sideData = av_frame_get_side_data(avframe, AV_FRAME_DATA_SEI_UNREGISTERED) {
                            let size = sideData.pointee.size
                            if size > AV_UUID_LEN {
                                let str = String(cString: sideData.pointee.data.advanced(by: Int(AV_UUID_LEN)))
                                options.sei(string: str)
                            }
                        }
                    }
                    var position = avframe.pointee.best_effort_timestamp
                    if position < 0 {
                        position = avframe.pointee.pts
                    }
                    if position < 0 {
                        position = avframe.pointee.pkt_dts
                    }
                    if position < 0 {
                        position = bestEffortTimestamp
                    }
                    frame.position = position
                    bestEffortTimestamp = position
                    bestEffortTimestamp += frame.duration
                    completionHandler(.success(frame))
                } catch {
                    completionHandler(.failure(error))
                }
            } else {
                if result == AVError.eof.code {
                    avcodec_flush_buffers(codecContext)
                    break
                } else if result == AVError.tryAgain.code {
                    break
                } else {
                    let error = NSError(errorCode: packet.assetTrack.mediaType == .audio ? .codecAudioReceiveFrame : .codecVideoReceiveFrame, avErrorCode: result)
                    MarblePlayerLog(error)
                    completionHandler(.failure(error))
                }
            }
        }
    }

    func doFlushCodec() {
        bestEffortTimestamp = Int64(0)
        if firstSeek {
            firstSeek = false
        } else {
            if codecContext != nil {
                avcodec_flush_buffers(codecContext)
            }
        }
    }

    func shutdown() {
        av_frame_free(&coreFrame)
        avcodec_free_context(&codecContext)
        swresample.shutdown()
    }

    func decode() {
        bestEffortTimestamp = Int64(0)
        if codecContext != nil {
            avcodec_flush_buffers(codecContext)
        }
    }
}
