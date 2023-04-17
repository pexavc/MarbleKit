//
//  MarbleEngine.Models.swift
//  Marble
//
//  Created by 0xKala on 8/8/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

import Foundation
import CoreVideo
import Metal

public struct MarbleLayer {
    public var layer: EffectType = .none
    
    public init(_ layer: EffectType) {
        self.layer = layer
    }
}

public struct MarbleResource {
    public struct Buffer {
        public var main: CVPixelBuffer?
        public var accessory: [CVPixelBuffer?]? = nil
        public var mainIsLandscape: Bool = false
        
        public init(
            main: CVPixelBuffer?,
            accessory: [CVPixelBuffer?]? = nil,
            mainIsLandscape: Bool = false) {
            self.main = main
            self.accessory = accessory
            self.mainIsLandscape = mainIsLandscape
        }
    }
    
    public struct Image {
        public var main: MarbleImage?
        public var accessory: [MarbleImage?]? = nil
        
        public init(
            main: MarbleImage?,
            accessory: [MarbleImage?]? = nil) {
            self.main = main
            self.accessory = accessory
        }
    }
    
    public struct Texture {
        public var main: MTLTexture?
        public var accessory: [MTLTexture?]? = nil
        public var isLandscape: Bool = false
        public init(
            main: MTLTexture?,
            accessory: [MTLTexture?]? = nil) {
            self.main = main
            self.accessory = accessory
        }
    }
    
    public var buffers: Buffer? = nil
    public var images: Image? = nil
    public var textures: Texture? = nil
    public var size: CGSize = .zero
    
    public var isBuffer: Bool {
        buffers != nil
    }
    
    public var isImage: Bool {
        images != nil
    }
    
    public var isTexture: Bool {
        textures != nil
    }
    
    public var isReadyToRender: Bool = false
    
    public init(
        buffers: Buffer? = nil,
        images: Image? = nil,
        textures: Texture? = nil,
        size: CGSize = .zero) {
        
        self.buffers = buffers
        self.images = images
        self.textures = textures
        self.size = size
    }
}

public struct MarbleComposite {
    public var resource: MarbleResource? = nil
    public var payload: MarbleCatalog.Payloads? = nil
    public var environment: MarbleCatalog.Environment? = nil
    public var layers: [MarbleLayer]
    
    public init(
        resource: MarbleResource? = nil,
        payload: MarbleCatalog.Payloads? = nil,
        environment: MarbleCatalog.Environment? = nil,
        layers: [MarbleLayer]) {
        
        self.resource = resource
        self.payload = payload
        self.environment = environment
        self.layers = layers
    }
}
