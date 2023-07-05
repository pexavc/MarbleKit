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

    public typealias UIViewType = MetalView
    
    public init() {
        
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeNSView(context: Context) -> MetalView {
        
        let metalView = context.coordinator.metalView
        
        metalView.mtkView.device = context.environment.marbleRemote?.metalContext.device
        metalView.mtkView.delegate = context.environment.marbleRemote
        metalView.apply(context.environment)
        
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        context.coordinator.scalingMode = context.environment.scalingMode
        context.coordinator.contentSize = context.environment.contentSize
        
        return metalView
    }
    
    public func updateNSView(_ nsView: MetalView, context: Context) {
        context.coordinator.metalView.apply(context.environment)
        
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        context.coordinator.scalingMode = context.environment.scalingMode
        context.coordinator.contentSize = context.environment.contentSize
        
        print("[MetalViewUI] \(context.environment.preferredFramesPerSecond)fps set")
    }
    
    public class Coordinator {
        
        private var cancellable: AnyCancellable?
        
        public var metalView: MetalView = {
            MetalView(frame: .zero)
        }()
        
        public var setNeedsDisplayTrigger: SetNeedsDisplayTrigger? {
            
            didSet {
                
                self.cancellable = self.setNeedsDisplayTrigger?.receive(on: DispatchQueue.main).sink { [weak self] in
                    
                    guard let self = self,
                          self.metalView.mtkView.isPaused,
                          self.metalView.mtkView.enableSetNeedsDisplay
                    else { return }
                    
                    self.metalView.setNeedsDisplay(self.metalView.bounds)
                    
                }
                
            }
            
        }
        
        public var contentSize : CGSize = CGSize(width: 640, height: 480) {
                
            didSet {
                DispatchQueue.main.async {
                    self.metalView.contentSize = self.contentSize
                }
            }
            
        }
        
        public var scalingMode : ScalingMode = .scaleAspectFit {
                
            didSet {
                DispatchQueue.main.async {
                    self.metalView.scalingMode = self.scalingMode
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

    public typealias UIViewType = MetalView
    
    public init() {
        
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeUIView(context: Context) -> MetalView {
        
        let metalView = context.coordinator.metalView
        
        metalView.mtkView.device = context.environment.marbleRemote?.metalContext.device
        metalView.mtkView.delegate = context.environment.marbleRemote
        metalView.apply(context.environment)
        
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        context.coordinator.scalingMode = context.environment.scalingMode
        context.coordinator.contentSize = context.environment.contentSize
        
        return metalView
    }
    
    public func updateUIView(_ nsView: MetalView, context: Context) {
        context.coordinator.metalView.apply(context.environment)
        
        context.coordinator.setNeedsDisplayTrigger = context.environment.setNeedsDisplayTrigger
        context.coordinator.scalingMode = context.environment.scalingMode
        context.coordinator.contentSize = context.environment.contentSize
        
        print("[MetalViewUI] \(context.environment.preferredFramesPerSecond)fps set")
    }
    
    public class Coordinator {
        
        private var cancellable: AnyCancellable?
        
        public var metalView: MetalView = {
            MetalView(frame: .zero)
        }()
        
        public var setNeedsDisplayTrigger: SetNeedsDisplayTrigger? {
            
            didSet {
                
                self.cancellable = self.setNeedsDisplayTrigger?.receive(on: DispatchQueue.main).sink { [weak self] in
                    
                    guard let self = self,
                          self.metalView.mtkView.isPaused,
                          self.metalView.mtkView.enableSetNeedsDisplay
                    else { return }
                    
                    self.metalView.setNeedsDisplay(self.metalView.bounds)
                    
                }
                
            }
            
        }
        
        public var contentSize : CGSize = CGSize(width: 640, height: 480) {
                
            didSet {
                DispatchQueue.main.async {
                    self.metalView.contentSize = self.contentSize
                }
            }
            
        }
        
        public var scalingMode : ScalingMode = .scaleAspectFit {
                
            didSet {
                DispatchQueue.main.async {
                    self.metalView.scalingMode = self.scalingMode
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
