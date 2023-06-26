//
//  MarbleRemoteConfig.swift
//  MarbleKit
//
//  Created by PEXAVC on 6/18/23.
//

import Foundation
import Network

public struct MarbleRemoteConfig: Equatable, Codable, Identifiable, Hashable {
    public var id: String {
        "\(date.timeIntervalSince1970)"
    }
    
    public var date: Date = .init()
    public var name: String
    public var kind: MarbleRemoteConfig.StreamConfig.Kind
    public var streams: [StreamConfig]
    
    public init(name: String,
                kind: MarbleRemoteConfig.StreamConfig.Kind,
                streams: [StreamConfig]) {
        self.name = name
        self.kind = kind
        self.streams = streams
    }
    
    public var description: String {
        name + "'s Stream on " + kind.rawValue.capitalized
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public enum Resolution: Int, Equatable, Codable, Identifiable, Comparable, CaseIterable {
        case p360 = 0
        case p540
        case p720
        case p1080
        
        public var id: Int { rawValue }
        
        var displayValue: String {
            switch self {
            case .p360: return "360p"
            case .p540: return "540p"
            case .p720: return "720p"
            case .p1080: return "1080p"
            }
        }
        
        var cgSize: CGSize {
            switch self {
            case .p1080:
                return .init(width: 1920, height: 1080)
            case .p720:
                return .init(width: 1280, height: 720)
            case .p540:
                return .init(width: 960, height: 540)
            case .p360:
                return .init(width: 640, height: 360)
            }
        }
        
        public static func ==(lhs: Resolution, rhs: Resolution) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
        
        public static func <(lhs: Resolution, rhs: Resolution) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    

    public struct StreamConfig: Equatable, Codable {
        public enum Kind: String, CaseIterable, Equatable, Codable {
            case kick
            case twitch
        }
        
        public var resolution: MarbleRemoteConfig.Resolution
        public var streamURL: URL
        
        public init(resolution: MarbleRemoteConfig.Resolution,
                    streamURL: URL) {
            self.resolution = resolution
            self.streamURL = streamURL
        }
    }
}
