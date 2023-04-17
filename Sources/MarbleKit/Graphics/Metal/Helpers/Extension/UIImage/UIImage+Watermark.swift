//
//  UIImage+Watermark.swift
//  Wonder
//
//  Created by 0xKala on 3/19/20.
//  Copyright © 2020 0xKala. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit

extension UIImage {
    func watermark(watermarkSize: CGSize, watermarkOffset: CGFloat) -> UIImage? {
        let backgroundImage = self
        guard let watermarkImage = UIImage(named: "watermark") else {
            return nil
        }

        UIGraphicsBeginImageContextWithOptions(backgroundImage.size, false, 0.0)
        backgroundImage.draw(in: CGRect(x: 0.0, y: 0.0, width: backgroundImage.size.width, height: backgroundImage.size.height))
        watermarkImage.draw(in: CGRect(x: watermarkOffset, y: watermarkOffset, width: watermarkSize.width, height: watermarkSize.height))

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result
    }
}
#endif
