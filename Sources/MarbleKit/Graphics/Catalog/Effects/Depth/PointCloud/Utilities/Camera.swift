//
//  Camera.swift
//  Marble
//
//  Created by 0xKala on 8/13/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

import Foundation
import simd
#if os(OSX)
import Cocoa
#else
import UIKit
#endif

protocol CameraDelegate {
    func updatePinch(_ gesture: MarbleUXEvent?, scale: CGFloat)
    func updatePan(_ gesture: MarbleUXEvent?, point: CGPoint)
    func updateTap(_ gesture: MarbleUXEvent?)
    func updateRotate(_ gesture: MarbleUXEvent?, rotation: CGFloat)
    func updateCamera(
        withSize size: CGSize,
        withTextureSize textureSize: CGSize,
        orientation: Camera.Properties.Orientation,
        isRearCamera: Bool)
}

final class Camera {
    public struct Properties {
        var drawableSize: CGSize;
        var isRearCamera: Bool;
        var orientation: Orientation;
        var fov: FOV;
        
        public struct Orientation: Equatable {
            
            var isLandscapeLeft: Bool;
            var isLandscapeRight: Bool;
            
            
            var isLandscape: Bool {
                return isLandscapeLeft || isLandscapeRight
            }
            
            static var identity: Orientation {
                return .init(
                    isLandscapeLeft: false,
                    isLandscapeRight: false)
            }
            
            var identityUP: Float {
                return isLandscape ? -1 : 1
            }
        }
        
        public struct FOV: Equatable {
            var cameraFOV: Float;
            var center: simd_float3
            var eye: simd_float3
            var up: simd_float3
            
            static var identity: FOV {
                return .init(
                    cameraFOV: 100,
                    center: .init(0, 0, 600),
                    eye: .init(),
                    up: .init(1, 0, 0))
            }
            
            static var identityLandscape: FOV {
                return .init(
                    cameraFOV: 100,
                    center: .init(0, 0, 600),
                    eye: .init(),
                    up: .init(-1, 0, 0))
            }
        }
    }
    
    enum Thresholds {
        static let eyeZ: Float = 120
        static let scalingFactor: Float = 1/12
        
        static let vFOV: Float = 120
        static let portraitVFOV: Float = 120
        static let landscapeVFOV: Float = 160
        static let scaleVFOV: Float = 40
    }
    
    func matrix4Multiply3(
        _ m: simd_float4x4,
        v: simd_float3) -> simd_float3 {
        
        var temp: simd_float4 = .init(v.x, v.y, v.z, 0.0)
        temp = simd_mul(m, temp)
        
        return .init(temp.x, temp.y, temp.z)
    }
    
    private(set) var properties: Properties
    private let projection: Projection = .init()
    
    public var isReady: Bool = false
    
    private var liveCENTER: simd_float3   // current point camera looks at
    private var liveEYE: simd_float3     // current camera position
    private var liveUP: simd_float3
    
    private var lastLiveScale: Float = 1.0
    private var lastLiveRotation: Float = 0.0
    private var lastLivePan: CGPoint = .zero
    private var lastLiveFOV: Float = 120
    
    private(set) var autoPanningIndex: Int = 0
    
    private(set) public var pansTotal: Int = 400
    
    private let renderingQueue: DispatchQueue
    
    init(startingPan: Int = 0) {
        self.autoPanningIndex = startingPan
        
        renderingQueue = .init(
            label: "marblekit.catalog.depth.camera",
            qos: .userInitiated,
            attributes: .init(),
            autoreleaseFrequency: .workItem,
            target: DispatchQueue.global(qos: .userInitiated))
        
        self.properties = .init(
            drawableSize: .zero,
            isRearCamera: false,
            orientation: Properties.Orientation.identity,
            fov: Properties.FOV.identity)
        
        liveCENTER = Properties.FOV.identity.center
        liveEYE = Properties.FOV.identity.eye
        liveUP = Properties.FOV.identity.up
    }
    
    func start(
        _ drawableSize: CGSize,
        fov: Properties.FOV = .identity) {
        properties.drawableSize = drawableSize
        
        if fov == .identity {
            reset()
        } else {
            properties.fov = fov
            self.syncCamera(live: true)
        }
        
        self.isReady = true
    }
    
    func reset() {
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            
            if self.properties.orientation.isLandscape {
                self.properties.fov = .identityLandscape
            } else {
                self.properties.fov = .identity
            }
            
            self.syncCamera(live: true)
        }
    }
    
    func syncCamera(live: Bool = false) {
        if live {
            self.liveCENTER = self.properties.fov.center
            self.liveEYE = self.properties.fov.eye
            self.liveUP = self.properties.fov.up
        } else {
            self.properties.fov.center = self.liveCENTER
            self.properties.fov.eye = self.liveEYE
            self.properties.fov.up = self.liveUP
        }
    }
    
    func updatePan(_ index: Int) {
        guard index < pansTotal else { return }
        for _ in 0..<index {
            animate()
        }
    }
    
    func updateZoom(_ zoom: Float) {
        self.lastLiveFOV = zoom
    }
}

extension Camera {
    func updateOrientation(
        _ orientation: Camera.Properties.Orientation,
        textureIsLandscape: Bool) {
        
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            
            if self.properties.orientation != orientation {
                self.properties.orientation = orientation
                
                self.liveUP.x = orientation.identityUP
                
                self.syncCamera(live: true)
            }
            
            guard textureIsLandscape == self
                    .properties
                    .drawableSize
                    .isLandscape else {
                return
            }
            
            let drawableSize = self.properties.drawableSize
            if textureIsLandscape {
                
                self.properties.drawableSize = .init(
                    width: min(drawableSize.width,
                               drawableSize.height),
                    height: max(drawableSize.width,
                                drawableSize.height))
                self.lastLiveFOV = Camera.Thresholds.vFOV
            } else {
                self.properties.drawableSize = .init(
                    width: max(drawableSize.width,
                               drawableSize.height),
                    height: min(drawableSize.width,
                                drawableSize.height))
                self.lastLiveFOV = Camera.Thresholds.vFOV - Camera.Thresholds.scaleVFOV
            }
        }
    }
    
    func updateDeviceCamera(
        _ isRearCamera: Bool) {
        guard self.properties.isRearCamera != isRearCamera else {
            return
        }
        
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            
            self.properties.isRearCamera = isRearCamera
        }
    }
    
    func getProjection() -> (matrix: simd_float4x4, z: Float){
        let aspect: Float = Float(
            properties.drawableSize.width / properties.drawableSize.height)
        let projectionMatrix: simd_float4x4 = Projection
            .perspectiveFOV(
                lastLiveFOV,
                aspect,
                0.01,
                30000)
        
        var mutableLiveFOV: Camera.Properties.FOV = .identity
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            
            var stagingEYE = self.liveEYE
            
            if Camera.Thresholds.eyeZ < self.liveEYE.z {
                stagingEYE.z = Camera.Thresholds.eyeZ
                self.liveEYE = stagingEYE
            }
            
            mutableLiveFOV.center = self.liveCENTER
            mutableLiveFOV.eye = stagingEYE
            mutableLiveFOV.up = self.liveUP
        }
        
        let viewMatrix = Projection.lookAt(
            mutableLiveFOV.eye,
            mutableLiveFOV.center,
            mutableLiveFOV.up)
        return ((projectionMatrix * viewMatrix), z: mutableLiveFOV.eye.z)
    }
    
    func restartAnimation() {
        autoPanningIndex = 0
    }
    
    func stopAnimation() {
        autoPanningIndex = -1
    }
}

extension Camera {
    
    func rotateAroundCenter(_ angle: Float) {
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            
            let rotDiff: Float = (angle) - self.lastLiveRotation
            
            let viewDir: simd_float3 = simd_normalize(self.liveCENTER - self.liveEYE)
            let rotMat: simd_float4x4 = Projection.rotate((rotDiff) * 60, viewDir)
            
            self.liveUP = self.matrix4Multiply3(rotMat, v: self.liveUP)
            self.lastLiveRotation = angle
        }
    }
    
    func rollAroundCenter(_ point: CGPoint) {
        guard point != .zero else {
            lastLivePan = point
            return
        }
        
        stopAnimation()
        
        let speed: CGFloat = 0.075
        
        if self.properties.orientation.isLandscape {
            yawAroundCenter(
                Float((point.y - lastLivePan.y) * speed * (self.properties.isRearCamera && self.properties.orientation.isLandscapeLeft ? -1 : 1)))
            pitchAroundCenter(
                Float((point.x - lastLivePan.x) * speed * (self.properties.isRearCamera && self.properties.orientation.isLandscapeRight ? -1 : 1)))
        }else {
            yawAroundCenter(Float((point.x - lastLivePan.x) * speed))
            pitchAroundCenter(Float((point.y - lastLivePan.y) * speed))
        }
        lastLivePan = point
    }
    
    func yawAroundCenter(_ angle: Float) {
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            
            let rotMat: simd_float4x4 = Projection.rotate(angle, self.liveUP)
            
            if self.properties.orientation.isLandscapeLeft {
                self.liveEYE = self.liveEYE - self.liveCENTER
                self.liveEYE = self.matrix4Multiply3(rotMat, v: self.liveEYE)
                self.liveEYE = self.liveEYE + self.liveCENTER
            } else {
                self.liveEYE = self.liveEYE + self.liveCENTER
                self.liveEYE = self.matrix4Multiply3(rotMat, v: self.liveEYE)
                self.liveEYE = self.liveEYE - self.liveCENTER
            }
            
            //FEATURE: This can be toggled (changes movement behavior)
            self.liveUP = self.matrix4Multiply3(rotMat, v: self.liveUP)
        }
    }
    
    func pitchAroundCenter(_ angle: Float) {
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            
            let viewDir: simd_float3 = simd_normalize(self.liveCENTER - self.liveEYE)
            let rightVector: simd_float3 = simd_cross(self.liveUP, viewDir)
            let rotMat: simd_float4x4 = Projection.rotate(angle, rightVector)
            
            self.liveEYE = self.liveEYE + self.liveCENTER
            self.liveEYE = self.matrix4Multiply3(rotMat, v: self.liveEYE)
            self.liveEYE = self.liveEYE - self.liveCENTER
            
            //FEATURE: This can be toggled (changes movement behavior)
            self.liveUP = self.matrix4Multiply3(rotMat, v: self.liveUP)
        }
    }
    
    func moveTowardCenter(_ scale: Float) {
        guard scale != 1.0 else {
            self.lastLiveScale = 1.0
            return
        }
        
        var mutableLiveScale = scale
        renderingQueue.sync { [weak self] in
            guard let self = self else { return }
            let diff: Float = (Float(scale) - self.lastLiveScale)
            self.lastLiveScale = scale
            let factor: Float = 1e3
            mutableLiveScale = diff * factor
            
            var direction: simd_float3 = self.liveCENTER - self.liveEYE
            
            //Prevents moving to the other side of the subject
            let distance = sqrt(simd_dot(direction, direction))
            if scale > distance {
                mutableLiveScale = (distance - 3.0)
            }
           
            direction = simd_normalize(direction)
            direction *= mutableLiveScale
            direction.z *= Thresholds.scalingFactor
            
            self.liveEYE += direction
        }
    }
}

extension Camera {
    func animate() {
        if self.autoPanningIndex >= 0 {
            reset()

            let moves = pansTotal

            let factor = 2.0 * .pi / Double(moves)

            let pitch = sin(Double(self.autoPanningIndex) * factor) * 2
            let yaw = cos(Double(self.autoPanningIndex) * factor) * 2
            self.autoPanningIndex = (self.autoPanningIndex + 1) % moves
            
            yawAroundCenter(Float(yaw) * 2)
            rotateAroundCenter(Float(pitch) * 2)
        }
    }
}

