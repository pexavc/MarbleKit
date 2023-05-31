//
//  Atlas.swift
//  Marble
//
//  Created by PEXAVC on 8/8/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

import AVFoundation
import Foundation

//MOVE TO AN EXT File
extension Int {
    func randomBetween(_ secondNum: Int) -> Int{
        guard secondNum > 0 else { return 0 }
        
        return Int.random(in: self..<secondNum)
    }
}

#if canImport(UIKit)
import UIKit
import Photos

open class Atlas: NSObject {
    var displayLink: MarbleDisplayLink?
    fileprivate let imageManager = PHCachingImageManager()
    
    var currentPayload: MarbleCatalog.Payloads? = nil
    var upcomingPayload: MarbleCatalog.Payloads? = nil
    
    public var consumer: ((MarbleCatalog.Payloads?) -> ())?
    var lastTime: CMTime = .zero
    
    var isDownloadingNextPayload: Bool = false
    var isDisplayOnly: Bool = false
    
    var payloadFetchIndex: Int = 0
    var payloadFetchLimit: Int = 240
    
    var currentContributionIndex: Int = 0
    var totalContributions: Int = 0
    var cache: [Int:MarbleCatalog.Payloads?] = [:]
    
    //
    let maxDim: CGFloat
    let contributions: [PHAsset]
    //
    public let id: String = UUID().uuidString
    
    public init?(
        _ contributions: [PHAsset] = [],
        displayOnly: Bool = true,
        consumer callback: @escaping(MarbleCatalog.Payloads?)  -> Void) {
        
        self.maxDim = max(MarbleCatalog.Const.defaultRes.width, MarbleCatalog.Const.defaultRes.height)
        self.contributions = contributions
        consumer = callback
        
        self.isDisplayOnly = displayOnly
        
        super.init()
        
        start()
        
    }
    
    public init(_ gameLoop: ((MarbleCatalog.Payloads?) -> ())?) {
        self.consumer = gameLoop
        
        self.contributions = []
        self.maxDim = max(MarbleCatalog.Const.defaultRes.width, MarbleCatalog.Const.defaultRes.height)
//        self.consumer = nil
        super.init()
        
        self.isDisplayOnly = true
    }
    
    public func start() {
        displayLink = MarbleDisplayLink(target: self, selector: #selector(displayLinkDidRefresh))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
    }
    
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        consumer = nil
    }
    
    
    @objc func displayLinkDidRefresh(link: MarbleDisplayLink) {
        
        update()
        
        payloadFetchIndex = (self.payloadFetchIndex + 1) % payloadFetchLimit
    }
    
    func update() {
        
        // This condition is here because Atlas
        // is still in charge of maintaining the 30fps
        // draw call on the metalView it is hosted within
        //
        // would be nice to abstract this defining memory
        // issue....
        //
        if !isDownloadingNextPayload, !isDisplayOnly,
           payloadFetchIndex >= payloadFetchLimit-1 || currentContributionIndex == 0 {
            self.payloadFetchIndex = 0
            self.isDownloadingNextPayload = true
            image(
                forAsset: contributions[0.randomBetween(contributions.count)],
                size: .init(
                    width: MarbleCatalog.Const.defaultRes.width,
                    height: MarbleCatalog.Const.defaultRes.height)) { [weak self] (image, isDegraded) in
                
                guard !isDegraded, let image = image else { return }
                
                UIGraphicsBeginImageContext(image.size)
                image.draw(at: .zero)
                let outputImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
                let buffer: CVPixelBuffer? = outputImage
                    .pixelBuffer(
                        width: Int(outputImage.size.width),
                        height: Int(outputImage.size.height))
                
                let payload: MarbleCatalog.Payloads = .init(
                    resource: .init(
                        buffers: .init(
                            main: buffer,
                            mainIsLandscape: outputImage.size.isLandscape)))
                
                
                self?.consumer?(payload)
                self?.currentContributionIndex += 1
                self?.isDownloadingNextPayload = false
            }
        } else {
            consumer?(nil)
        }
    }
    
    @discardableResult
    func image(forAsset asset: PHAsset, size: CGSize, isNeedDegraded: Bool = true, completion: @escaping ((UIImage?, Bool) -> Void)) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        return imageManager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFit,
            options: options,
            resultHandler: { (image, info) in
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                if !isNeedDegraded && isDegraded {
                    return
                }
                DispatchQueue.main.async {
                    completion(image, isDegraded)
                }
        })
    }
}

#elseif os(OSX)
import AppKit
import Photos
import CoreVideo
import Cocoa

open class Atlas: NSObject {
    lazy var operation: OperationQueue = {
        var op = OperationQueue.init()
        op.qualityOfService = .background
        op.maxConcurrentOperationCount = 1
        op.name = "atlas.frame.operation"
        return op
    }()
    
    var _displayLink: MarbleDisplayLink?
    var _displaySource: DispatchSourceUserDataAdd?
    fileprivate let imageManager = PHCachingImageManager()
    
    var currentPayload: MarbleCatalog.Payloads? = nil
    var upcomingPayload: MarbleCatalog.Payloads? = nil
    
    public var consumer: ((MarbleCatalog.Payloads?) -> ())?
    var lastTime: CMTime = .zero
    
    var isDownloadingNextPayload: Bool = false
    var isDisplayOnly: Bool = false
    
    var payloadFetchIndex: Int = 0
    var payloadFetchLimit: Int = 240
    
    var currentContributionIndex: Int = 0
    var totalContributions: Int = 0
    var cache: [Int:MarbleCatalog.Payloads?] = [:]
    
    //
    let contributions: [PHAsset] = []
    //
    
    public let id: String = UUID().uuidString
    
    public init(_ gameLoop: ((MarbleCatalog.Payloads?) -> ())?) {
        self.consumer = gameLoop
        
        super.init()
        
        _displaySource = DispatchSource.makeUserDataAddSource(queue: DispatchQueue.main)
        _displaySource!.setEventHandler {[weak self] in
            self?.operation.addOperation { [weak self] in
                self?.update()
            }
        }
        _displaySource!.resume()
        
        var cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink)
                   
        assert(cvReturn == kCVReturnSuccess)

        cvReturn = CVDisplayLinkSetOutputCallback(_displayLink!, dispatchGameLoop, Unmanaged.passUnretained(_displaySource!).toOpaque())

        assert(cvReturn == kCVReturnSuccess)

        cvReturn = CVDisplayLinkSetCurrentCGDisplay(_displayLink!, CGMainDisplayID () )

        assert(cvReturn == kCVReturnSuccess)
    }
    
    public func start() {
        CVDisplayLinkStart(_displayLink!)
    }
    
    public func stop() {
        CVDisplayLinkStop(_displayLink!)
        _displaySource?.cancel()
        operation.cancelAllOperations()
        _displayLink = nil
        consumer = nil
    }
    
    private let dispatchGameLoop: CVDisplayLinkOutputCallback = {
        displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext in
    
        let source = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(displayLinkContext!).takeUnretainedValue()
        source.add(data: 1)
        
    
        return kCVReturnSuccess
    }
    
    
    @objc func displayLinkDidRefresh(link: MarbleDisplayLink) {
        guard _displayLink != nil else {
            CVDisplayLinkStop(link)
            return
        }
        operation.addOperation { [weak self] in
            self?.update()
        }
    }
    
    func update() {
        consumer?(nil)
    }
}



//*************** NETWORK/DB POWERED *******************/

//if  (currentPayload == nil || payloadFetchIndex >= payloadFetchLimit-1) &&
//    !isDownloadingNextPayload {
//
//    isDownloadingNextPayload = true
//
//
//    if  cache.keys.contains(currentContributionIndex),
//        let cachedPayload = cache[currentContributionIndex] {
//        self.upcomingPayload = cachedPayload
//        update()
//    } else {
//        AtlasCommands.download(
//            index: currentContributionIndex) {
//                (depthPayload, skinPayload, atlasPayload) in
//
//                self.upcomingPayload = (depthPayload, skinPayload, atlasPayload)
//                self.cache.updateValue(self.upcomingPayload, forKey: self.currentContributionIndex)
//                self.update()
//        }
//    }
//}
//
//if  let depthPayload = currentPayload?.0,
//    let skinPayload = currentPayload?.1,
//    let atlasPayload = currentPayload?.2{
//
//    consumer(depthPayload, skinPayload, atlasPayload)
//}
#endif
