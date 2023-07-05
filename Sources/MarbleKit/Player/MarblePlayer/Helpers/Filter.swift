//
//  Filter.swift
//  MarbleKit.Player
//
// https://github.com/kingslay/KSPlayer/blob/develop/Sources/KSPlayer/MEPlayer/Filter.swift
//  Created by kintan on 2021/8/7.
//

import Foundation
import Libavfilter
import Libavutil
class MarblePlayerFilter {
    private var graph: UnsafeMutablePointer<AVFilterGraph>?
    private var bufferContext: UnsafeMutablePointer<AVFilterContext>?
    private var bufferSinkContext: UnsafeMutablePointer<AVFilterContext>?
    private var outputFrame = av_frame_alloc()
    private var filters: String?
    private let timebase: Timebase
    private let isAudio: Bool
    private var params = AVBufferSrcParameters()
    private let nominalFrameRate: Float
    deinit {
        graph?.pointee.opaque = nil
        avfilter_graph_free(&graph)
        av_frame_free(&outputFrame)
    }

    public init(timebase: Timebase, isAudio: Bool, nominalFrameRate: Float, options: MarblePlayerOptions) {
        graph = avfilter_graph_alloc()
        graph?.pointee.opaque = Unmanaged.passUnretained(options).toOpaque()
        self.timebase = timebase
        self.isAudio = isAudio
        self.nominalFrameRate = nominalFrameRate
    }

    private func setup(filters: String) -> Bool {
        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        defer {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
        }
        var ret = avfilter_graph_parse2(graph, filters, &inputs, &outputs)
        guard ret >= 0, let graph, let inputs, let outputs else {
            return false
        }
        let bufferSink = avfilter_get_by_name(isAudio ? "abuffersink" : "buffersink")
        ret = avfilter_graph_create_filter(&bufferSinkContext, bufferSink, "out", nil, nil, graph)
        guard ret >= 0 else { return false }
        ret = avfilter_link(outputs.pointee.filter_ctx, UInt32(outputs.pointee.pad_idx), bufferSinkContext, 0)
        guard ret >= 0 else { return false }
        let buffer = avfilter_get_by_name(isAudio ? "abuffer" : "buffer")
        bufferContext = avfilter_graph_alloc_filter(graph, buffer, "in")
        guard bufferContext != nil else { return false }
        av_buffersrc_parameters_set(bufferContext, &params)
        ret = avfilter_init_str(bufferContext, nil)
        guard ret >= 0 else { return false }
        ret = avfilter_link(bufferContext, 0, inputs.pointee.filter_ctx, UInt32(inputs.pointee.pad_idx))
        guard ret >= 0 else { return false }
        var hwDeviceCtx: UnsafeMutablePointer<AVBufferRef>?
        av_hwdevice_ctx_create(&hwDeviceCtx, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, nil, nil, 0)
        if let hwDeviceCtx {
            (0 ..< graph.pointee.nb_filters).forEach { i in
                graph.pointee.filters[Int(i)]?.pointee.hw_device_ctx = av_buffer_ref(hwDeviceCtx)
            }
        }
        ret = avfilter_graph_config(graph, nil)
        guard ret >= 0 else { return false }
        return true
    }

    public func filter(options: MarblePlayerOptions,
                       inputFrame: UnsafeMutablePointer<AVFrame>,
                       hwFramesCtx: UnsafeMutablePointer<AVBufferRef>?) -> UnsafeMutablePointer<AVFrame> {
        let filters: String
        if isAudio {
            filters = options.audioFilters.joined(separator: ",")
        } else {
            if options.autoDeInterlace, !options.videoFilters.contains("idet") {
                options.videoFilters.append("idet")
            }
            filters = options.videoFilters.joined(separator: ",")
        }
        guard filters.count > 0 else {
            return inputFrame
        }
        var params = AVBufferSrcParameters()
        params.format = inputFrame.pointee.format
        params.time_base = timebase.rational
        params.width = inputFrame.pointee.width
        params.height = inputFrame.pointee.height
        params.sample_aspect_ratio = inputFrame.pointee.sample_aspect_ratio
        params.frame_rate = AVRational(num: 1, den: Int32(nominalFrameRate))
        params.hw_frames_ctx = hwFramesCtx
        params.sample_rate = inputFrame.pointee.sample_rate
        params.ch_layout = inputFrame.pointee.ch_layout
        if self.params != params || self.filters != filters {
            self.params = params
            self.filters = filters
            if !setup(filters: filters) {
                return inputFrame
            }
        }
        if graph?.pointee.sink_links_count == 0 {
            return inputFrame
        }
        var ret = av_buffersrc_add_frame_flags(bufferContext, inputFrame, Int32(AV_BUFFERSRC_FLAG_KEEP_REF))
        guard ret == 0 else { return inputFrame }
        av_frame_unref(outputFrame)
        ret = av_buffersink_get_frame_flags(bufferSinkContext, outputFrame, 0)
        guard ret == 0 else { return inputFrame }
        return outputFrame ?? inputFrame
    }
}
