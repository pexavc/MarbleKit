//
//  File.swift
//  
//
//  Created by 0xKala on 11/9/20.
//
#if !os(macOS)
import Metal
import MetalKit
import ARKit
import Foundation
import SwiftUI
import Combine

public protocol MetalViewARUIDelegate {
    func updateTexture(_ texture: MTLTexture?)
}

public class MetalViewAR: MTKView {
    private var isPrepared: Bool = false
    private var renderer: AREngine!
    
    public func update(session: ARSession) {
        guard let device = MTLCreateSystemDefaultDevice(), !isPrepared else {
            return
        }
        
        isPrepared = true
        
        self.device = device
        self.delegate = self
        self.backgroundColor = UIColor.clear
        // we need this to enable depth test
        self.depthStencilPixelFormat = .depth32Float
        self.contentScaleFactor = 1
        self.renderer = AREngine(session: session, metalDevice: device, renderDestination: self)
        renderer.drawRectResized(size: self.bounds.size)
        
        let configuration = ARWorldTrackingConfiguration()
        if #available(iOS 14, *) {
            configuration.frameSemantics = .sceneDepth
        }

        // Run the view's session
        session.run(configuration)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
}

extension MetalViewAR: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    public func draw(in view: MTKView) {
        renderer.draw()
    }
}

public struct MetalViewARUI: MarbleRepresentable {
    @Binding var texture: MTLTexture?
    @Binding var metalView: MetalViewAR
    
    public func updateUIView(_ uiView: MetalViewAR, context: Context) {

    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: MarbleRepresentableContext<MetalViewARUI>) -> MetalViewAR {
        return metalView
    }
    
    public class Coordinator : NSObject, MetalViewARUIDelegate {
        var parent: MetalViewARUI
        
        init(_ parent: MetalViewARUI) {
            self.parent = parent
            super.init()
        }
        
        public func updateTexture(_ texture: MTLTexture?) {
            
        }
    }
    
    public init(texture: Binding<MTLTexture?>, metalView: Binding<MetalViewAR>) {
        self._texture = texture
        self._metalView = metalView
    }
}
#endif
