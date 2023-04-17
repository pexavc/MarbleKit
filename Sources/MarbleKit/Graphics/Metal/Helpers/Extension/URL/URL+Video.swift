//
//  URL.swift
//  Wonder
//
//  Created by 0xKala on 8/18/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

import AVFoundation

extension URL {
    func resolutionSizeForLocalVideo(_ ignoreTransform: Bool = false) -> CGSize? {
        guard let track = AVAsset(url: self).tracks(withMediaType: AVMediaType.video).first else { return nil }
        
        let size = ignoreTransform ? track.naturalSize : track.naturalSize.applying(track.preferredTransform)
        
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    func removeFromTemp(){
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            do {
                try fileManager.removeItem(atPath: path)
            } catch let error {
                
            }
        }
    }
    
    func saveTo(path: String, completion: @escaping ((URL?) -> Void)) {
        path.clearFromTemp()
        
        let avAsset = AVAsset(url: self)
        let outputURL = URL(fileURLWithPath: path)
        
        avAsset.save(toURL: URL(fileURLWithPath: path)) { (success) in
            
            if success {
                completion(outputURL)
            } else {
                completion(nil)
            }
        }
    }
}
