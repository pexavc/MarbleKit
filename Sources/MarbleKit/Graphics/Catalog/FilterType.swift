//
//  FilterType.swift
//  Wonder
//
//  Created by 0xKala on 8/14/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import Cocoa
#endif

public enum EffectType {
    //Sample, Threshold
    case none
    case analog(Float, Int)
    case pixellate(Float, Float)
    case disco(Float, Float)
    case drive(Float, Float)
    case ink(Float)
    case vibes(Float, Float)
    case depth(Float)
    case bokeh(Float, Float)
    case backdrop(Float)
    case scale(Float)
    case skin(Float, Float)
    case godRay(Float, Float)
    case polka(Float, Float)
    case stars(Float, Float)
    
    public var isNone : Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
}

public enum MarbleEffect {
    //Sample, Threshold
    case none
    case analog
    case pixellate
    case disco
    case drive
    case ink
    case vibes
    case depth
    case bokeh
    case godRay
    case polka
    case stars
    
    public func getLayer(_ sample: Float, threshold: Float = 1.0) -> EffectType {
        switch self {
        case .analog:
            return .analog(sample, Int(threshold))
        case .pixellate:
            return .pixellate(sample, threshold)
        case .disco:
            return .disco(sample, threshold)
        case .drive:
            return .drive(sample, threshold)
        case .ink:
            return .ink(sample)
        case .vibes:
            return .vibes(sample, threshold)
        case .depth:
            return .depth(threshold)
        case .bokeh:
            return .bokeh(sample, threshold)
        case .godRay:
            return .godRay(sample, threshold)
        case .polka:
            return .polka(sample, threshold)
        case .stars:
            return .stars(sample, threshold)
        case .none:
            return .none
        }
    }
}
