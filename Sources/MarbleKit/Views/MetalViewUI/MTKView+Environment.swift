//
//  File.swift
//  
//
//  Created by Alessandro Toschi on 02/01/22.
//

import SwiftUI
import MetalKit

extension MTKView {
    
    @discardableResult
    func apply(_ environment: EnvironmentValues) -> Self {

        self.colorPixelFormat = environment.colorPixelFormat
        self.framebufferOnly = environment.framebufferOnly
        if let drawableSize = environment.drawableSize {
            self.drawableSize = drawableSize
        }
        self.autoResizeDrawable = environment.autoResizeDrawable
        self.clearColor = environment.clearColor
        self.preferredFramesPerSecond = environment.preferredFramesPerSecond
        self.enableSetNeedsDisplay = environment.enableSetNeedsDisplay
        self.isPaused = environment.isPaused
        self.presentsWithTransaction = environment.presentWithTransaction
        return self
        
    }
    
}

extension MetalView {
    
    @discardableResult
    func apply(_ environment: EnvironmentValues) -> Self {

        self.mtkView.colorPixelFormat = environment.colorPixelFormat
        self.mtkView.framebufferOnly = environment.framebufferOnly
        if let drawableSize = environment.drawableSize {
            self.mtkView.drawableSize = drawableSize
        }
        self.mtkView.autoResizeDrawable = environment.autoResizeDrawable
        self.mtkView.clearColor = environment.clearColor
        self.mtkView.preferredFramesPerSecond = environment.preferredFramesPerSecond
        self.mtkView.enableSetNeedsDisplay = environment.enableSetNeedsDisplay
        self.mtkView.isPaused = environment.isPaused
        self.mtkView.presentsWithTransaction = environment.presentWithTransaction
        return self
        
    }
    
}
