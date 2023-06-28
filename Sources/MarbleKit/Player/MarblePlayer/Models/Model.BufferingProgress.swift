//
//  File.swift
//  
//
//  Created by PEXAVC on 6/27/23.
//

import AudioToolbox
import Foundation
import AVFAudio
import Accelerate

public final class BufferingProgress: NSObject, ObservableObject {
    public static var shared: BufferingProgress = .init()
    
    public struct Stats: Equatable {
        public var progress: Int
        public var loadState: MarbleMediaLoadState
        public var isDropping: Bool = false
    }
    
    @Published public var stats: Stats = .init(progress: 0, loadState: .idle)
    
    var progress: Int = 0
    var loadState: MarbleMediaLoadState = .idle
    var isDropping: Bool = false
    
    var operationQueue: OperationQueue = .init()
    
    private let queue: DispatchQueue = .init(label: "marblekit.buffering.asset", qos: .userInteractive)
    
    override public init() {
        
        super.init()
        self.operationQueue.underlyingQueue = queue
        self.operationQueue.maxConcurrentOperationCount = 1
    }
    
    func update(loadState: MarbleMediaLoadState) {
        switch loadState {
        case .idle:
            progress = 0
        default:
            break
        }
        
        self.loadState = loadState
        
        self.operationQueue.addOperation {
            DispatchQueue.main.async {
                self.stats = .init(progress: self.progress, loadState: self.loadState)
            }
        }
    }
    
    func update(progress: Int) {
        self.progress = progress
        
        self.operationQueue.addOperation {
            DispatchQueue.main.async {
                self.stats = .init(progress: self.progress, loadState: self.loadState)
            }
        }
    }
    
    func update(clockType: ClockProcessType) {
        guard self.stats.isDropping != self.isDropping else { return }
        self.operationQueue.addOperation {
            DispatchQueue.main.async {
                self.stats = .init(progress: self.progress, loadState: self.loadState, isDropping: clockType == .drop)
            }
        }
    }
}
