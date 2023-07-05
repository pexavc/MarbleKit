//
//  MarblePlayerResource.swift
//  MarbleKit
//
//  Created by kintan on 16/5/21.
//
//

import AVFoundation
import Foundation
import MediaPlayer

public class MarblePlayerResource: Hashable {
    public static func == (lhs: MarblePlayerResource, rhs: MarblePlayerResource) -> Bool {
        lhs.definitions == rhs.definitions
    }

    public let name: String
    public let cover: URL?
    public let definitions: [MarblePlayerResourceDefinition]
    public var nowPlayingInfo: MarbleNowPlayableMetadata?
    public let extinf: [String: String]?
    /**
     Player recource item with url, used to play single difinition video

     - parameter name:      video name
     - parameter url:       video url
     - parameter cover:     video cover, will show before playing, and hide when play
     - parameter subtitleURLs: video subtitles
     */
    public convenience init(url: URL, options: MarblePlayerOptions = MarblePlayerOptions(), name: String = "", cover: URL? = nil, subtitleURLs: [URL]? = nil, extinf: [String: String]? = nil) {
        let definition = MarblePlayerResourceDefinition(url: url, definition: "", options: options)

        self.init(name: name, definitions: [definition], cover: cover, extinf: extinf)
    }

    /**
     Play resouce with multi definitions

     - parameter name:        video name
     - parameter definitions: video definitions
     - parameter cover:       video cover
     - parameter subtitle:   video subtitle
     */
    public init(name: String, definitions: [MarblePlayerResourceDefinition], cover: URL? = nil, extinf: [String: String]? = nil) {
        self.name = name
        self.cover = cover
        self.definitions = definitions
        self.extinf = extinf
        nowPlayingInfo = MarbleNowPlayableMetadata(title: name)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(definitions)
    }
}

extension MarblePlayerResource: Identifiable {
    public var id: MarblePlayerResource { self }
}

public class MarblePlayerResourceDefinition: Hashable {
    public static func == (lhs: MarblePlayerResourceDefinition, rhs: MarblePlayerResourceDefinition) -> Bool {
        lhs.url == rhs.url
    }

    public let url: URL
    public let definition: String
    public let options: MarblePlayerOptions
    public convenience init(url: URL) {
        self.init(url: url, definition: url.lastPathComponent)
    }

    /**
     Video recource item with defination name and specifying options

     - parameter url:        video url
     - parameter definition: url deifination
     - parameter options:    specifying options for the initialization of the AVURLAsset
     */
    public init(url: URL, definition: String, options: MarblePlayerOptions = MarblePlayerOptions()) {
        self.url = url
        self.definition = definition
        self.options = options
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

extension MarblePlayerResourceDefinition: Identifiable {
    public var id: MarblePlayerResourceDefinition { self }
}

public struct MarbleNowPlayableMetadata {
    private let mediaType: MPNowPlayingInfoMediaType?
    private let isLiveStream: Bool?
    private let title: String
    private let artist: String?
    private let artwork: MPMediaItemArtwork?
    private let albumArtist: String?
    private let albumTitle: String?
    var nowPlayingInfo: [String: Any] {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = mediaType?.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        if #available(OSX 10.13.2, *) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        nowPlayingInfo[MPMediaItemPropertyAlbumArtist] = albumArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        return nowPlayingInfo
    }

    init(mediaType: MPNowPlayingInfoMediaType? = nil, isLiveStream: Bool? = nil, title: String, artist: String? = nil,
         artwork: MPMediaItemArtwork? = nil, albumArtist: String? = nil, albumTitle: String? = nil)
    {
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
    }

    init(mediaType: MPNowPlayingInfoMediaType? = nil, isLiveStream: Bool? = nil, title: String, artist: String? = nil, image: MarbleImage, albumArtist: String? = nil, albumTitle: String? = nil) {
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
        artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
