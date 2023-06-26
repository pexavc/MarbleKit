////
////  File.swift
import SwiftUI
import MetalKit
import Combine


public protocol MetalViewUIDelegate: MTKViewDelegate {
    var metalContext: MetalContext { get set }
}

#if os(OSX)
public struct MetalViewUI: NSViewRepresentable {
    
    public typealias SetNeedsDisplayTrigger = AnyPublisher<Void, Never>

    public enum DrawingMode {
        
        case timeUpdates(preferredFramesPerSecond: Int)
        case drawNotifications(setNeedsDisplayTrigger: SetNeedsDisplayTrigger?)
        
    }

    public typealias UIViewType = MTKView
    
    public var metalContext: MetalContext
    private weak var remote: MetalViewUIDelegate?
    
    public init(remote: MetalViewUIDelegate?) {
        self.remote = remote
        self.metalContext = .init(context: remote?.metalContext)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeNSView(context: Context) -> MTKView {
        
        let metalView = context.coordinator.metalView
        metalView.device = self.metalContext.device
        metalView.delegate = self.remote
        metalView.apply(context.environment)
        
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        
        return metalView
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        
        context.coordinator.metalView.apply(context.environment)
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        print("UPDATE VIEW \(nsView.framebufferOnly)")
    }
    
    public class Coordinator {
        
        private var cancellable: AnyCancellable?
        
        public var metalView: MTKView = {
            MTKView(frame: .zero)
        }()
        
        public var setNeedsDisplayTrigger: SetNeedsDisplayTrigger? {
            
            didSet {
                
                self.cancellable = self.setNeedsDisplayTrigger?.receive(on: DispatchQueue.main).sink { [weak self] in
                    
                    guard let self = self,
                          self.metalView.isPaused,
                          self.metalView.enableSetNeedsDisplay
                    else { return }
                    
                    self.metalView.setNeedsDisplay(self.metalView.bounds)
                    
                }
                
            }
            
        }
        
        public init() {
            
            self.cancellable = nil
            self.setNeedsDisplayTrigger = nil
            
        }
        
    }
    
}
#else
public struct MetalViewUI: UIViewRepresentable {
    
    public typealias SetNeedsDisplayTrigger = AnyPublisher<Void, Never>

    public enum DrawingMode {
        
        case timeUpdates(preferredFramesPerSecond: Int)
        case drawNotifications(setNeedsDisplayTrigger: SetNeedsDisplayTrigger?)
        
    }

    public typealias UIViewType = MTKView
    
    public var metalContext = MetalContext()
    private weak var renderer: MetalViewUIDelegate?
    
    public init(renderer: MetalViewUIDelegate?) {
        self.renderer = renderer
        self.renderer?.metalContext = metalContext
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeUIView(context: Context) -> MTKView {
        
        let metalView = context.coordinator.metalView
        metalView.device = self.metalContext.device
        metalView.delegate = self.renderer
        metalView.apply(context.environment)
        
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        
        return metalView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        
        context.coordinator.metalView.apply(context.environment)
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        print("UPDATE VIEW")
    }
    
    public class Coordinator {
        
        private var cancellable: AnyCancellable?
        
        public var metalView: MTKView = {
            MTKView(frame: .zero)
        }()
        
        public var setNeedsDisplayTrigger: SetNeedsDisplayTrigger? {
            
            didSet {
                
                self.cancellable = self.setNeedsDisplayTrigger?.receive(on: DispatchQueue.main).sink { [weak self] in
                    
                    guard let self = self,
                          self.metalView.isPaused,
                          self.metalView.enableSetNeedsDisplay
                    else { return }
                    
                    self.metalView.setNeedsDisplay()
                    
                }
                
            }
            
        }
        
        public init() {
            
            self.cancellable = nil
            self.setNeedsDisplayTrigger = nil
            
        }
        
    }
    
}
#endif


//
//
//  Created by PEXAVC on 2/26/21.
//

import Foundation
import SwiftUI
import MetalKit

protocol MarbleGestureProxyDelegate {
    func gesturesUpdated(_ state: MarbleGestureProxy.Payload)
}
public class MarbleGestureProxy: NSObject, MarbleRecognizerDelegate {
    var delegate: MarbleGestureProxyDelegate?

    public struct MarbleScroll {
        public var deltaX: CGFloat
        public var deltaY: CGFloat//starts at 1
        public var deltaZ: CGFloat
        public var state: MarbleUXEvent

        var limit: CGFloat = 400
        public var normalizedY: CGFloat {
            //can go from 0 - 3 essentially for scroll based magnification
            return (max(0, deltaY/(limit/MarbleScale.limit)))
        }
    }

    public struct MarbleScale {
        public var pinch: MarblePinch
        public var scale: CGFloat
        var lastScale: CGFloat = 0.0

        static var limit: CGFloat = 4.8
    }

    lazy var pan : MarblePan = {
        let gesture : MarblePan = .init(target: self,
                                action: #selector(handleGestures(_:)))

        gesture.delegate = self

        #if os(iOS)
        gesture.cancelsTouchesInView = false
        #endif
        return gesture
    }()

    lazy var pinch : MarblePinch = {
        let gesture : MarblePinch = .init(target: self,
                            action: #selector(handleGestures(_:)))

        gesture.delegate = self

        #if os(iOS)
        gesture.cancelsTouchesInView = false
        #endif
        return gesture
    }()

    lazy var rotate : MarbleRotate = {
        let gesture : MarbleRotate = .init(target: self,
                            action: #selector(handleGestures(_:)))

        gesture.delegate = self

        #if os(iOS)
        gesture.cancelsTouchesInView = false
        #endif
        return gesture
    }()

    var compiled: Payload {
        .init(pan: pan, scale: scale, rotate: rotate, scroll: scroll)
    }

    lazy var scale: MarbleScale = {
        .init(pinch: pinch, scale: 0.0)
    }()

    var scroll: MarbleScroll = .init(deltaX: 0, deltaY: 1.0, deltaZ: 0, state: .possible)

    @objc public func handleGestures(
            _ gestureRecognizer: MarbleRecognizer) {

        if let pinchG = gestureRecognizer as? MarblePinch {
            let newScale = (pinchG.scale - 1.0)
            let newScaleDiff = newScale - scale.lastScale
            scale.scale = (pinchG.state == .changed || pinchG.state == .began) ? max(0, min(MarbleScale.limit, newScaleDiff + scale.scale)) : scale.scale

            if pinchG.state == .ended {
                scale.lastScale = 0.0
            }
        }

        delegate?.gesturesUpdated(self.compiled)

    }

    public func updateScroll(_ newScroll: MarbleScroll) {
//        scroll.deltaX += newScroll.deltaX
        scroll.deltaY = newScroll.state == .changed || newScroll.state == .began ? max(0, min(newScroll.deltaY + scroll.deltaY, scroll.limit)) : scroll.deltaY
//        scroll.deltaZ += newScroll.deltaZ
        scroll.state = newScroll.state
        compiled.rotate.rotation = 0.0

//        compiled.scroll = scroll
    }

    public func gestureRecognizer(
        _ gestureRecognizer: MarbleRecognizer,
        shouldRecognizeSimultaneouslyWith
            otherGestureRecognizer: MarbleRecognizer) -> Bool {
        return true
    }

    #if os(iOS)
    public func gestureRecognizer(
        _ gestureRecognizer: MarbleRecognizer,
        shouldReceive touch: UITouch) -> Bool {

        return true
    }
    #endif

    public struct Payload {
        public let pan: MarblePan
        public let scale: MarbleScale
        public let rotate: MarbleRotate
        public var scroll: MarbleScroll
    }
}

public struct MetalViewOptions: Equatable {
    public var scalingMode: ScalingMode
    public var rotation: Float
    public var contentSize: CGSize
    public var startingZoom: CGFloat

    public static var basic: MetalViewOptions {
        .init(scalingMode: .scaleAspectFit,
              rotation: 0,
              contentSize: .init(width: 1920, height: 1080),
              startingZoom: 0)
    }

    public static var empty: MetalViewOptions {
        .init(scalingMode: .scaleAspectFit,
              rotation: 0,
              contentSize: .zero,
              startingZoom: 0)
    }
}

//#if os(OSX)
//import AppKit
//public protocol MetalViewUIDelegate {
//    func updateTexture(_ texture: MTLTexture?)
//}
//public struct MetalViewUI: MarbleRepresentable {//}, MarbleGestureProxyDelegate {
////    @Binding var texture: MTLTexture?
////    @Binding var metalView: MetalView
////    var callback: ((MarbleGestureProxy.Payload) -> Void)?
//
////    public init(texture: Binding<MTLTexture?>,
////                metalView: Binding<MetalView>,
////                _ callback: ((MarbleGestureProxy.Payload) -> Void)?){
////        self._texture = texture
////        self._metalView = metalView
////        self.callback = callback
////        self.metalView.gestures.delegate = self
////    }
//
//    @Binding public var texture: MTLTexture?
//    @Binding public var options: MetalViewOptions
//
//    var callback: ((MarbleGestureProxy.Payload) -> Void)?
//
//    public init(texture: Binding<MTLTexture?>,
//                options: Binding<MetalViewOptions>){
//        self._texture = texture
//        self._options = options
//    }
//
//    public func updateNSView(_ nsView: MetalView, context: Context) {
//        nsView.currentTexture = texture
//    }
//
////    public func makeCoordinator() -> Coordinator {
////        Coordinator(self)
////    }
//
////    func gesturesUpdated(_ state: MarbleGestureProxy.Payload) {
////        callback?(metalView.gestures.compiled)
////    }
//
//    public func makeNSView(context: MarbleRepresentableContext<MetalViewUI>) -> MetalView {
//        let metalView: MetalView = .init(frame: .init(origin: .zero, size: .init(width: 1920, height: 1080)))
//        metalView.gestures.delegate = context.coordinator
////        context.coordinator.callback = callback
//        return metalView
//    }
//
//    public func makeCoordinator() -> Coordinator {
//        return .init()
//    }
//
//    public class Coordinator : NSObject, MarbleGestureProxyDelegate {
//        var callback: ((MarbleGestureProxy.Payload) -> Void)?
//
//        override init() {}
//
//        func gesturesUpdated(_ state: MarbleGestureProxy.Payload) {
//            callback?(state)
//        }
//    }
//}
//#else
//public protocol MetalViewUIDelegate {
//    func updateTexture(_ texture: MTLTexture?)
//}
//public struct MetalViewUI: MarbleRepresentable {
//    @Binding public var texture: MTLTexture?
//    @Binding public var options: MetalViewOptions
//
//    var callback: ((MarbleGestureProxy.Payload) -> Void)?
//
//    public init(texture: Binding<MTLTexture?>,
//                options: Binding<MetalViewOptions>){
//        self._texture = texture
//        self._options = options
//    }
//
//    public func updateUIView(_ uiView: MetalView, context: Context) {
//        uiView.currentTexture = texture
//    }
//
//    public func makeUIView(context: MarbleRepresentableContext<MetalViewUI>) -> MetalView {
//        let metalView: MetalView = .init()
//        metalView.gestures.delegate = context.coordinator
//        context.coordinator.callback = callback
//        return metalView
//    }
//
//    public func makeCoordinator() -> Coordinator {
//        return .init()
//    }
//
//    public class Coordinator : NSObject, MarbleGestureProxyDelegate {
//        var callback: ((MarbleGestureProxy.Payload) -> Void)?
//
//        override init() {}
//
//        func gesturesUpdated(_ state: MarbleGestureProxy.Payload) {
//            callback?(state)
//        }
//    }
//}
//#endif
