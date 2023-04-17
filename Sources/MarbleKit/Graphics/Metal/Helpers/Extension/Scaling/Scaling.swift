//
//  Scaline.swift
//  Wonder
//
//  Created by 0xKala on 8/13/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import Foundation
import CoreGraphics
#if os(macOS)
#else
import UIKit
#endif

public enum ScalingMode {
    
    case scaleToFill
    
    case scaleAspectFit // contents scaled to fit with fixed aspect. remainder is transparent
    
    case scaleAspectFill // contents scaled to fill with fixed aspect. some portion of content may be clipped.
    
    case center // contents remain same size. positioned adjusted.
    
    case top
    
    case bottom
    
    case left
    
    case right
    
    case topLeft
    
    case topRight
    
    case bottomLeft
    
    case bottomRight
    
    #if os(macOS)
    #else
    public init(contentMode: UIView.ContentMode) {
        switch contentMode {
        case .scaleToFill:
            self = .scaleToFill
        case .scaleAspectFit:
            self = .scaleAspectFit
        case .scaleAspectFill:
            self = .scaleAspectFill
        case .redraw:
            self = .scaleToFill
        case .center:
            self = .center
        case .top:
            self = .top
        case .bottom:
            self = .bottom
        case .left:
            self = .left
        case .right:
            self = .right
        case .topLeft:
            self = .topLeft
        case .topRight:
            self = .topRight
        case .bottomLeft:
            self = .bottomLeft
        case .bottomRight:
            self = .bottomRight
        @unknown default:
            self = .scaleAspectFit
        }
    }
    #endif
    
    init(renderingMode: PORenderingViewMode) {
        switch renderingMode {
        case .scaleAspectFit:
            self = .scaleAspectFit
        case .scaleAspectFill:
            self = .scaleAspectFill
        }
    }
}

public enum PORenderingViewMode {
    case scaleAspectFit
    case scaleAspectFill
}
