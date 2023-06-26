//
//  MarblePlayerView.swift
//  
//
//  Created by PEXAVC on 6/25/23.
//

import Foundation
import SwiftUI

public struct MarblePlayerView: View {
    @State var fps: Int = 30
    
    public init(_ config: MarbleRemoteConfig) {
        MarbleRemote.current = .init(config: config)
    }
    
    public var body: some View {
        MetalViewUI(remote: MarbleRemote.current)
            .drawingMode(.timeUpdates(preferredFramesPerSecond: fps))
            .onReceive(MarbleRemote.current.$fps) { newFPS in
                guard self.fps != Int(newFPS) else { return }
                self.fps = Int(newFPS)
            }
    }
}