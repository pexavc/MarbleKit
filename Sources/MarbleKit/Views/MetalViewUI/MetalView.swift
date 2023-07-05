//
//  MetalView.swift
//  Wonder
//
//  Created by PEXAVC on 8/13/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
import MetalKit

public protocol MetalViewDelegate: class {
    func drawableCallback(_ texture: MTLTexture)
}

open class MetalView: MarbleBaseView {
    weak var delegate: MetalViewDelegate?
    public var gestures: MarbleGestureProxy = .init()
    
    public var currentTexture: MTLTexture? {
        
        didSet {
            mtkView.draw()
        }
    }
    
    public var contentSize : CGSize = CGSize(width: 640, height: 480) {
        
        didSet {
            DispatchQueue.main.async {
                self.layoutMetalView()
            }
        }
        
    }
    
    public var scalingMode : ScalingMode = .scaleAspectFit {
        
        didSet {
            DispatchQueue.main.async {
                self.layoutMetalView()
            }
        }
        
    }
    
    public var videoAspect: CGFloat = 1.3333 {
        didSet {
            contentSize = CGSize(width: contentSize.height * videoAspect, height: 480)
        }
    }
    
    public let mtkView = MTKView()
    public var metalContext = MetalContext()
    
    public var watermark: MarbleImage? = nil {
        didSet {
            setupWatermarkTexture(contentSize)
        }
    }
    
    public var assetNaturalSize: CGSize? = nil {
        didSet{
            checkNaturalSize()
        }
    }
    
    public var assetNaturalSizeNotTransformed: CGSize = .zero
    
    var assetIsTooLarge: Bool = false
    
    public var inputVideoRotation: Float = 0.0
    
    public var maxSize: CGSize = CGSize(width: 1920, height: 1080)
    
    public var watermarkOffset: Float = 20.0
    public var watermarkSize: CGSize = .zero
    public var watermarkTexture: MTLTexture?
    public var showWatermark: Bool = true
    
    var scaledTextureDescriptor: MTLTextureDescriptor?
    
    public struct TransformOptions {
        var referenceFrame: CGRect = .zero
        
        //TODO: Adjust for various screen sizes
        let translationSpeed: CGPoint = CGPoint(x: MarbleCatalog.Const.envSizeMin, y: 120.0)
        
        var rotation: CGFloat = 0.0 {
            didSet {
                lastRotation = lastRotation + rotation
                finalRotation = lastRotation
            }
        }
        var lastRotation: CGFloat = 0.0
        var finalRotation: CGFloat = 0.0
        
        
        var scale: CGFloat = 0.0 {
            didSet {
                lastScale = scale - 1.0
                
                let scaleToBe = finalScale + lastScale
                if scaleToBe >= 1.0 && scaleToBe <= 2.0 {
                    finalScale = scaleToBe
                }
            }
        }
        var lastScale: CGFloat = 1.0
        var finalScale: CGFloat = 1.0
        
        var translation: CGPoint = .zero {
            didSet {
                
                lastTranslation = CGPoint(x: (lastTranslation.x + translation.x + (translationSpeed.x * translation.x < 0 ? -1 : 1)),
                                          y: (lastTranslation.y + translation.y + (translationSpeed.y * translation.y < 0 ? -1 : 1)))
                finalTranslation = CGPoint(x: (lastTranslation.x)/MarbleCatalog.Const.envSizeMin,
                                           y: (lastTranslation.y)/MarbleCatalog.Const.envSizeMin)
                
            }
        }
        var lastTranslation: CGPoint = .zero
        var finalTranslation: CGPoint = .zero
        
        mutating func resetTranslation() {
            lastTranslation = .zero
            finalTranslation = .zero
        }
        
        mutating func resetScale() {
            lastScale = 1.0
            finalScale = 1.0
        }
        
        mutating func resetRotation() {
            finalRotation = 0.0
        }
        
        mutating func reset() {
            resetTranslation()
            resetScale()
            resetRotation()
        }
    }
    
    public var transformOptions: TransformOptions = TransformOptions()
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetalView()
    }
    
    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        
//        mtkView.device = metalContext.device
//        mtkView.delegate = self
//        mtkView.framebufferOnly = false
//        mtkView.enableSetNeedsDisplay = true
//        mtkView.isPaused = true
        
        scalingMode = .scaleAspectFill
        
        setupMetalView()
    }
    
    #if os(iOS) || os(watchOS) || os(tvOS)
    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutMetalView()
        
    }
    #else
    public override func layout() {
        super.layout()
        layoutMetalView()
    }
    #endif
    
    fileprivate func setupMetalView() {
//        scalingMode = .scaleAspectFit
        addGestureRecognizer(gestures.pan)
        addGestureRecognizer(gestures.pinch)
        addGestureRecognizer(gestures.rotate)
        
        #if os(iOS) || os(watchOS) || os(tvOS)
        setBackgroundColor(color: UIColor(white: 0.0, alpha: 1.0).cgColor)
        #else
        setBackgroundColor(color: NSColor(white: 0.0, alpha: 1.0).cgColor)
        #endif
        
        self.addSubview(mtkView)
    }
    
    fileprivate func layoutMetalView() {
        let metalFrame = contentSize.position(
            in: bounds.size,
            with: scalingMode).rounded
        mtkView.frame = metalFrame
        
        let maxContentSizeDim = max(contentSize.width, contentSize.height)
        let minMTKDim = min(mtkView.drawableSize.width, mtkView.drawableSize.height)
        let maxMTKDim = max(mtkView.drawableSize.width, mtkView.drawableSize.height)
        
        let newSize: CGSize = .init(width: minMTKDim/maxMTKDim * maxContentSizeDim, height: maxContentSizeDim)
        
        if contentSize.isLandscape {
            self.mtkView.drawableSize = newSize.swappedSize
        } else {
            self.mtkView.drawableSize = newSize
        }
        
    }
    
    func makeStandardScreen(){
        contentSize = CGSize(width: contentSize.height * videoAspect, height: contentSize.height)
    }
    
    func makeFullScreen(){
//        if videoAspect > 1.0 {
//            contentSize = CGSize(width: WKConst.Device.isIPhoneX ? contentSize.height * 2.166 : contentSize.height * 1.777, height: contentSize.height)
//        }
    }
    
    func setBackgroundColor(color: CGColor) {
        #if os(iOS) || os(watchOS) || os(tvOS)
        self.layer.backgroundColor = color
        #else
        self.layer?.backgroundColor = color
        #endif
    }
    
    func toggleWatermark(){
        showWatermark.toggle()
    }
    
    func checkNaturalSize(){
        guard let naturalSize = self.assetNaturalSize else { return }
        
        if max(naturalSize.width, naturalSize.height) > max(maxSize.width, maxSize.height) ||
            min(naturalSize.width, naturalSize.height) > min(maxSize.width, maxSize.height) {

            let frame = CGSize(width: naturalSize.width, height: naturalSize.height).position(in: maxSize, with: scalingMode).rounded

            scaledTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(frame.size.width), height: Int(frame.size.height), mipmapped: false)
            scaledTextureDescriptor?.usage = [.shaderRead, .shaderWrite]

            assetIsTooLarge = true

            contentSize = frame.size

            //Reset Watermark size
            setupWatermarkTexture(frame.size)
        }
    }
    
    func setupWatermarkTexture(_ size: CGSize){
        do {
            var watermarkWidth = 0.046*max(contentSize.height, contentSize.width)
            var watermarkHeight = 0.266*watermarkWidth
            
            //Changed from long variant to straight logo
            //So match sides to create a square
            //
            watermarkWidth = watermarkHeight

            watermarkWidth *= 0.84
            watermarkHeight *= 0.84
            
            if max(contentSize.width, contentSize.height) > 640 {
                
            } else {
                watermarkOffset = 10
            }
            
            watermarkSize = CGSize(width: watermarkWidth, height: watermarkHeight)
            
            if let watermarkCheck = watermark,
               let watermarkCGImage = watermarkCheck.scaleImage(toNewSize: watermarkSize) {
                
                
                #if os(OSX)
                var rect: CGRect = .init(origin: .zero, size: watermarkCGImage.size)
                if let cgImage = watermarkCGImage.cgImage(
                    forProposedRect: &rect,
                    context: NSGraphicsContext.current,
                    hints: nil) {
                        let metalImage = try MetalImage(image: cgImage, context: self.metalContext)
                        watermarkTexture = metalImage.texture
                    }
                #else
                    
                    if let cgImage = watermarkCGImage.cgImage {
                        let metalImage = try MetalImage(image: cgImage, context: self.metalContext)
                        watermarkTexture = metalImage.texture
                    }
                #endif
                
            }
        } catch {
            
        }
    }
    
    #if os(macOS)
    open override func scrollWheel(with event: NSEvent) {
        gestures.updateScroll(.init(deltaX: event.deltaX, deltaY: event.deltaY, deltaZ: event.deltaZ, state: event.phase == .began ? .began : (event.phase == .changed ? .changed : .ended)))
        
        //TODO: MAJOR, NO, but why was this needed (prior was mOS 11.0)?
        gestures.delegate?.gesturesUpdated(.init(pan: .init(), scale: .init(pinch: .init(), scale: .infinity), rotate: .init(), scroll: .init(deltaX: .infinity, deltaY: .infinity, deltaZ: .infinity, state: .began)))
    }
    
    
    #endif
    
//    override func draw(_ rect: CGRect) {
//        if let img = image {
//            let scale = self.window?.screen.scale ?? 1.0
//            let destRect = bounds.applying(CGAffineTransform(scaleX: scale, y: scale))
//            coreImageContext.draw(img, in: destRect, from: img.extent)
//        }
//    }
}

extension MetalView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    public func draw(in view: MTKView) {
        autoreleasepool {
            guard let drawable = view.currentDrawable,
                let inputTexture = currentTexture,
                let commandBuffer = self.metalContext
                    .commandQueue
                    .makeCommandBuffer() else {
                    return
            }
            
            let transform = CGAffineTransform.identity
                .rotated(
                    by: CGFloat(
                        abs(inputVideoRotation - 180).radiansValue))
           
            if let mediamTexture = metalContext
                .kernels
                .transform
                .prepareTransformedTexture(
                    withInputTexture: inputTexture,
                    transform: transform) {
                
                metalContext.kernels.transform.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: inputTexture,
                    outputTexture: mediamTexture,
                    transform: transform)
                
                metalContext.kernels.downsample.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: mediamTexture,
                    outputTexture: drawable.texture)
                
            } else {
                metalContext.kernels.downsample.encode(
                    commandBuffer: commandBuffer,
                    inputTexture: inputTexture,
                    outputTexture: drawable.texture)
            }
            
            commandBuffer.addCompletedHandler { commandBuffer in
                self.delegate?.drawableCallback(inputTexture)
            }
        
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
