//
//  FunctionalMetal.swift
//  Wonder
//
//  Created by 0xKala on 8/14/19.
//  Copyright © 2019 0xKala. All rights reserved.
//
import AVFoundation
import Foundation
import MetalKit
#if os(iOS)
#elseif os(OSX)
import Cocoa
#endif

public typealias MetalFilter = (MTLTexture?) -> MTLTexture?

public struct MarbleCatalog {
    public struct Payloads {
        public var skin: SkinPayload? = nil
        public var depth: DepthPayload? = nil
        public var atlas: AtlasPayload? = nil
        public var resource: MarbleResource? = nil
        
        public init(skin: SkinPayload? = nil,
                    depth: DepthPayload? = nil,
                    atlas: AtlasPayload? = nil,
                    resource: MarbleResource? = nil) {
            self.skin = skin
            self.depth = depth
            self.atlas = atlas
            self.resource = resource
        }
        public var allAvailable: Bool {
            return skin != nil && depth != nil && atlas != nil
        }
    }
    
    public struct Environment {
        public struct Actions {
            public let isPaused: Bool
            public let isRestarting: Bool
            
            public init(isPaused: Bool, isRestarting: Bool) {
                self.isPaused = isPaused
                self.isRestarting = isRestarting
            }
        }
        
        public struct Gestures {
            enum Thresholds {
                static let pinch: CGFloat = 2.4
            }
            public var pinch: (MarbleUXEvent?, CGFloat) = (nil, .zero)
            public var pan: (MarbleUXEvent?, CGPoint) = (nil, .zero)
            public var tap: MarbleUXEvent? = nil
            public var rotate: (MarbleUXEvent?, CGFloat) = (nil, .zero)
            public var scroll: (MarbleUXEvent?, CGFloat) = (nil, .zero)
            public var threshold: (CGFloat) = (0.5)
            
            public init(
                pinch: (MarbleUXEvent?, CGFloat) = (nil, .zero),
                pan: (MarbleUXEvent?, CGPoint) = (nil, .zero),
                tap: MarbleUXEvent? = nil,
                rotate: (MarbleUXEvent?, CGFloat) = (nil, .zero),
                scroll: (MarbleUXEvent?, CGFloat) = (nil, .zero),
                threshold: (CGFloat) = (0.5)) {
                
                self.pinch = pinch
                self.pan = pan
                self.tap = tap
                self.rotate = rotate
                self.threshold = threshold
                self.scroll = scroll
            }
            
            mutating public func reset() {
                tap = (nil)
            }
            
            public static func prepare(
                _ gestures: Gestures,
                willSet events: (
                    pan: MarbleUXEvent,
                    pinch: MarbleUXEvent,
                    rotate: MarbleUXEvent,
                    scroll: MarbleUXEvent)) -> (
                    identityPan: CGPoint?,
                    identityPinch: CGFloat?,
                    identityRotate: CGFloat?) {
                
                var identities: (CGPoint?, CGFloat?, CGFloat?) = (nil, nil, nil)
                if  events.pan == .began ||
                    events.pan == .ended ||
                    events.pinch == .began {
                    
                    identities.0 = gestures.pan.1
                }
                
                if  events.pinch == .changed {
                    identities.1 = Gestures.Thresholds.pinch
                } else {
                    identities.1 = 1.0
                }
                
                if  events.rotate == .began ||
                    events.rotate == .ended ||
                    events.rotate == .possible {
                    
                    identities.2 = gestures.rotate.1
                }
                
                if  events.scroll == .changed {
                    identities.1 = Gestures.Thresholds.pinch
                } else {
                    identities.1 = 1.0
                }
                
                return identities
            }
        }
        
        public var actions: Actions
        public var gestures: Gestures
        
        public var isRearCamera: Bool = false
        public var isCamera: Bool = false
        public var isSkin: Bool = false
        public var isAtlas: Bool = false
        public var isLoadedSong: Bool = false
        public var isLandscapeLeft: Bool = false {
            didSet {
                if isLandscapeLeft {
                    isLandscapeRight = false
                }
            }
        }
        public var isLandscapeRight: Bool = false {
            didSet {
                if isLandscapeRight {
                    isLandscapeLeft = false
                }
            }
        }
        public var isBackdrop: Bool = false
        public var drawableSize: CGSize = MarbleCatalog.Const.defaultRes
        
        public var isLandscape: Bool {
            get {
                return isLandscapeLeft || isLandscapeRight
            }
            set {
                isLandscapeLeft = true
                isLandscapeRight = false
            }
        }
        
        public init(
            actions: MarbleCatalog.Environment.Actions,
            gestures: MarbleCatalog.Environment.Gestures) {
            self.actions = actions
            self.gestures = gestures
        }
        
        
        mutating public func updateGestures(_ gestures: Gestures) {
            self.gestures = gestures
        }
        
        mutating public func updateActions(_ actions: Actions) {
            self.actions = actions
        }
    }
    
    public struct SkinPayload {
        public var skinTexture: MTLTexture
        public var skinIsExclusive: Bool
        public var skinPlaceholdBuffer: CIImage?
        public var mode: Int = 0
    }
    
    public struct AtlasPayload {
        public var authorName: String
        public var envIntensity: Float
        public var totalContributions: Int = 1
    }
}

extension MarbleCatalog {
    public struct Const {
        public static var screenSize: CGSize {
            #if os(iOS)
            return UIScreen.main.bounds.size
            #elseif os(OSX)
            let millimetersPerInch:CGFloat = 25.4
            
            if let screenDescription = NSScreen.main?.deviceDescription,
               let displayUnitSize = (screenDescription[NSDeviceDescriptionKey.size] as? NSValue)?.sizeValue,
                let screenNumber = (screenDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value {
                let displayPhysicalSize = CGDisplayScreenSize(screenNumber)
                return CGSize(width: millimetersPerInch * displayUnitSize.width / displayPhysicalSize.width,
                              height: millimetersPerInch * displayUnitSize.height / displayPhysicalSize.height)
            } else {
                return CGSize(width: 72.0, height: 72.0) // this is the same as what CoreGraphics assumes if no EDID data is available from the display device — https://developer.apple.com/documentation/coregraphics/1456599-cgdisplayscreensize?language=objc
            }
            #endif
        }
        
        public static var envSizeMin: CGFloat {
            min(screenSize.width, screenSize.height)
        }
        
        public static var envSizeMax: CGFloat {
            max(screenSize.width, screenSize.height)
        }
        
        public static var defaultRes: CGSize {
            CGSize(width: 1200, height: 1200)
            //CGSize(width: 1296, height: 2304)
        }
        
        public static var defaultHDRes: CGSize {
            CGSize(width: 1600, height: 1600)
        }
        
        public static var defaultResLandscape: CGSize {
            CGSize(width: 1200, height: 750)
            //CGSize(width: 1296, height: 2304)
        }
    }
}

extension MarbleCatalog {
    func transform(context: MetalContext,
                   transform: CGAffineTransform) -> MetalFilter {
        
        return { image in
           guard let image = image else { return nil }
           
           do {

            let mediamTexture = context.kernels.transform.prepareTransformedTexture(
                withInputTexture: image,
                transform: transform)

                guard let commandBuffer = context.commandQueue.makeCommandBuffer(),
                    let mediamTextureCheck = mediamTexture else {
                    return nil
                }

                context.kernels.transform.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: image,
                    outputTexture: mediamTextureCheck,
                    transform: transform)

                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()

                return mediamTextureCheck
            } catch let error {
               print("{ FunctionalMetal } Vibes \(error.localizedDescription)")
            }
           
           return nil
        }
    }
}

