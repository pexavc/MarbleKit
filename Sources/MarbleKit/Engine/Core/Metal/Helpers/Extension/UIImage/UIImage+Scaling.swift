//
//  UIImage+Scaling.swift
//  Wonder
//
//  Created by PEXAVC on 8/18/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

extension MarbleImage {
    func scaleImage(toNewSize size: CGSize) -> MarbleImage? {
        let renderer = GraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            self.draw(in: CGRect.init(origin: CGPoint.zero, size: size))
        }
        
        return image
    }
}

