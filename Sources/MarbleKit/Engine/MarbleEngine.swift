//
//  MarbleEngine.swift
//  Marble
//
//  Created by PEXAVC on 8/8/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

import Metal
import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
import Cocoa
#endif

open class MarbleEngine {
    let catalog: MarbleCatalog = .init()
    public func compile(fromContext context: MetalContext?,
                        forComposite composite: MarbleComposite) -> MarbleComposite {
        
        guard let context = context else { return composite }
        
        var composite: MarbleComposite = composite
        for layer in composite.layers {
            composite = apply(
                fromContext: context,
                type: layer.layer,
                forComposite: composite)
        }
        return composite
    }
    
    public init() {}
}

extension MarbleEngine {
    public func apply(
        fromContext context: MetalContext,
        type: EffectType,
        forComposite composite: MarbleComposite) -> MarbleComposite{
        
        var mutableComposite: MarbleComposite = composite
        var texture: MTLTexture? = composite.resource?.textures?.main
        
        switch type {
        case .depth(let value):
            guard let payload = composite.payload?.depth else { break }
            texture = catalog.depth(context: context, depthPayload: payload, threshold: value)(texture)
        case .analog(let sample, let type):
            texture = catalog.analog(context: context, type: type, threshold: sample)(texture)
        case .pixellate(let value, let sliderValue):
            texture = catalog.pixellate(context: context, threshold: value, sliderValue: sliderValue)(texture)
        case .disco(let value, let sliderValue):
            texture = catalog.disco(context: context, threshold: sinf(value), sliderValue: sliderValue)(texture)
        case .drive(let value, let sliderValue):
            texture = catalog.drive(context: context, threshold: sinf(value)*0.24, sliderValue: sliderValue)(texture)
        case .ink(let value):
            texture = catalog.ink(context: context, threshold: value)(texture)
        case .vibes(let value, let sliderValue):
            texture = catalog.vibes(context: context, threshold: value, sliderThreshold: sliderValue)(texture)
        case .polka(let value, let sliderValue):
            texture = catalog.polka(context: context, threshold: sinf(value), sliderValue: sliderValue)(texture)
        case .stars(let value, let sliderValue):
            texture = catalog.stars(context: context, threshold: sinf(value), sliderValue: sliderValue)(texture)
        case .bokeh(let value, let sliderValue):
            texture = catalog.bokeh(context: context, threshold: sinf(value*sliderValue))(texture)
        case .godRay(let threshold, let value):
            texture = catalog.godRay(context: context, threshold: sinf(threshold))(texture)
        default:
            break
        }
        
        mutableComposite.resource?.textures?.main = texture
        
        return mutableComposite
    }
}

extension MarbleEngine {
    public func snapshot(texture: MTLTexture?,
                         fromContext context: MetalContext?) -> Data? {
        guard let texture = texture, let context = context else { return nil }
        let transform = CGAffineTransform.identity
            .rotated(
                by: CGFloat(180.floatValue.radiansValue))
        guard let newTexture = catalog.transform(context: context, transform: transform)(texture) else {
            return nil
        }
        
        #if os(iOS)
            return CGImage.fromTexture(newTexture)?.png
        #elseif os(OSX)
        if let cgimage = CGImage.fromTexture(newTexture) {
            return NSImage.init(cgImage: cgimage, size: newTexture.size).png
        } else {
            return nil
        }
        #endif
    }
    
    public func rotate(imageData: Data, degrees: CGFloat = 180) -> MarbleImage? {
        return MarbleImage.init(data: imageData)?.rotate(degrees: degrees.floatValue)
    }
}
