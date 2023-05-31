//
//  File.swift
//  
//
//  Created by PEXAVC on 3/19/21.
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
public typealias MarbleImage = UIImage
public typealias MarbleBaseView = UIView
public typealias MarbleRepresentable = UIViewRepresentable
public typealias MarbleRepresentableContext = UIViewRepresentableContext
public typealias MarbleDisplayLink = CADisplayLink

public typealias MarblePan = UIPanGestureRecognizer
public typealias MarblePinch = UIPinchGestureRecognizer
public typealias MarbleRotate = UIRotationGestureRecognizer
public typealias MarbleRecognizer = UIGestureRecognizer
public typealias MarbleRecognizerDelegate = UIGestureRecognizerDelegate

#elseif os(OSX)
import AppKit
public typealias MarbleImage = NSImage
public typealias MarbleBaseView = NSView
public typealias MarbleRepresentable = NSViewRepresentable
public typealias MarbleRepresentableContext = NSViewRepresentableContext
public typealias MarbleDisplayLink = CVDisplayLink

public typealias MarblePan = NSPanGestureRecognizer
public typealias MarblePinch = NSMagnificationGestureRecognizer
public typealias MarbleRotate = NSRotationGestureRecognizer
public typealias MarbleRecognizer = NSGestureRecognizer
public typealias MarbleRecognizerDelegate = NSGestureRecognizerDelegate

#endif
