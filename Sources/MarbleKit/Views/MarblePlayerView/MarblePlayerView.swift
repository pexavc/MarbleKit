//
//  MarblePlayerView.swift
//  
//
//  Created by PEXAVC on 6/25/23.
//

import Foundation
import SwiftUI

public struct MarblePlayerView: View {
    @ObservedObject var remote: MarbleRemote
    
    let config: MarbleRemoteConfig
    
    public init(_ config: MarbleRemoteConfig) {
        MarbleRemote.current.shutdown()
        MarbleRemote.current = .init(config: config)
        self.config = config
        self.remote = .current
    }
    
    public var body: some View {
        MetalViewUI()
            .remote(.current)
            .preferredFramesPerSecond(Int($remote.fps.wrappedValue))
            .scalingMode(.scaleAspectFit)
            .contentSize(MarbleRemote.current.selectedResolution.cgSize)
    }
}
