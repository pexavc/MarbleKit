//
//  Projection.swift
//  Marble
//
//  Created by PEXAVC on 8/13/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

import Foundation
import simd

final class Projection {
    public static func radians(_ degress: Float) -> Float{
        return degress / 180.0 * .pi
    }
    
    func scale( _ x: Float,
                _ y: Float,
                _ z: Float) -> simd_float4x4
    {
        let element: simd_float4 = .init(x, y, z, 1.0)
        let v: simd_float4x4 = .init(
            element,
            element,
            element,
            element)
        
        return v
    }
    
    func translate( _ t: simd_float3) -> simd_float4x4
    {
        var M: simd_float4x4 = matrix_identity_float4x4
        M.columns.3.x = t.x
        M.columns.3.y = t.y
        M.columns.3.z = t.z
        
        return M
    }
    
    func translate( _ x: Float,
                _ y: Float,
                _ z: Float) -> simd_float4x4
    {
        let t: simd_float3 = .init(x, y, z)
        
        return translate(t)
    }
    
    public static func radiansOverPi(_ degrees: Float) -> Float
    {
        return (degrees / 180.0)
    }
}

extension Projection {
    public static func rotate(_ angle: Float,
                _ r: simd_float3) -> simd_float4x4
    {
        let a: Float = radiansOverPi(angle);
        var c: Float = 0.0;
        var s: Float = 0.0;
        
        // Computes the sine and cosine of pi times angle (measured in radians)
        // faster and gives exact results for angle = 90, 180, 270, etc.
        __sincospif(a, &s, &c);
        
        let k: Float = 1.0 - c;
        
        let u: simd_float3 = simd_normalize(r);
        let v: simd_float3 = s * u;
        let w: simd_float3 = k * u;
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = w.x * u.x + c;
        P.y = w.x * u.y + v.z;
        P.z = w.x * u.z - v.y;
        P.w = 0.0;
        
        Q.x = w.x * u.y - v.z;
        Q.y = w.y * u.y + c;
        Q.z = w.y * u.z + v.x;
        Q.w = 0.0;
        
        R.x = w.x * u.z + v.y;
        R.y = w.y * u.z - v.x;
        R.z = w.z * u.z + c;
        R.w = 0.0;
        
        S.x = 0.0;
        S.y = 0.0;
        S.z = 0.0;
        S.w = 1.0;
        
        let rotMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return rotMatrix
    }
    
    public static func rotate(_ angle: Float,
                _ x: Float,
                _ y: Float,
                _ z: Float) -> simd_float4x4
    {
        let r: simd_float3 = .init(x, y, z)
        
        return rotate(angle, r);
    }
}

extension Projection {
    func perspective(_ width: Float,
                     _ height: Float,
                     _ near: Float,
                     _ far: Float) -> simd_float4x4
    {
        let zNear: Float = 2.0 * near;
        let zFar: Float  = far / (far - near);
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = zNear / width;
        P.y = 0.0;
        P.z = 0.0;
        P.w = 0.0;
        
        Q.x = 0.0;
        Q.y = zNear / height;
        Q.z = 0.0;
        Q.w = 0.0;
        
        R.x = 0.0;
        R.y = 0.0;
        R.z = zFar;
        R.w = 1.0;
        
        S.x =  0.0;
        S.y =  0.0;
        S.z = -near * zFar;
        S.w =  0.0;
        
        let perspMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return perspMatrix
    }
    
    public static func perspectiveFOV(_ fovy: Float,
                     _ aspect: Float,
                     _ near: Float,
                     _ far: Float) -> simd_float4x4
    {
        let angle: Float  = radians(0.5 * fovy);
        let yScale: Float = 1.0/tan(angle)
        let xScale: Float = yScale / aspect;
        let zScale: Float = far / (far - near);
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = xScale;
        P.y = 0.0;
        P.z = 0.0;
        P.w = 0.0;
        
        Q.x = 0.0;
        Q.y = yScale;
        Q.z = 0.0;
        Q.w = 0.0;
        
        R.x = 0.0;
        R.y = 0.0;
        R.z = zScale;
        R.w = 1.0;
        
        S.x =  0.0;
        S.y =  0.0;
        S.z = -near * zScale;
        S.w =  0.0;
        
        let perspMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return perspMatrix
    }
    
    public static func perspectiveFOV(_ fovy: Float,
                         _ width: Float,
                         _ height: Float,
                         _ near: Float,
                         _ far: Float) -> simd_float4x4
    {
        let aspect: Float = width/height
        
        return perspectiveFOV(fovy, aspect, near, far);
    }
}

extension Projection {
    public static func lookAt(_ eye: simd_float3,
                     _ center: simd_float3,
                     _ up: simd_float3) -> simd_float4x4
    {
        let zAxis: simd_float3 = simd_normalize(center - eye);
        let xAxis: simd_float3 = simd_normalize(simd_cross(up, zAxis));
        let yAxis: simd_float3 = simd_cross(zAxis, xAxis);
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = xAxis.x;
        P.y = yAxis.x;
        P.z = zAxis.x;
        P.w = 0.0;
        
        Q.x = xAxis.y;
        Q.y = yAxis.y;
        Q.z = zAxis.y;
        Q.w = 0.0;
        
        R.x = xAxis.z;
        R.y = yAxis.z;
        R.z = zAxis.z;
        R.w = 0.0;
        
        S.x = -simd_dot(xAxis, eye);
        S.y = -simd_dot(yAxis, eye);
        S.z = -simd_dot(zAxis, eye);
        S.w = 1.0;
        
        let perspMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return perspMatrix
    }
    
    public static func lookAt(_ pEye: [Float],
                _ pCenter: [Float],
                _ pUp: [Float]) -> simd_float4x4
    {
        let eye: simd_float3 = .init(pEye[0], pEye[1], pEye[2]);
        let center: simd_float3 = .init(pCenter[0], pCenter[1], pCenter[2]);
        let up: simd_float3 = .init(pUp[0], pUp[1], pUp[2]);
        
        return lookAt(eye, center, up)
    }
}

extension Projection {
    func ortho2d(_ left: Float,
                 _ right: Float,
                 _ bottom: Float,
                 _ top: Float,
                 _ near: Float,
                 _ far: Float) -> simd_float4x4
    {
        let sLength: Float = 1.0 / (right - left)
        let sHeight: Float = 1.0 / (top   - bottom)
        let sDepth: Float = 1.0 / (far   - near)
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = 2.0 * sLength;
        P.y = 0.0;
        P.z = 0.0;
        P.w = 0.0;
        
        Q.x = 0.0;
        Q.y = 2.0 * sHeight;
        Q.z = 0.0;
        Q.w = 0.0;
        
        R.x = 0.0;
        R.y = 0.0;
        R.z = sDepth;
        R.w = 1.0;
        
        S.x =  0.0;
        S.y =  0.0;
        S.z = -near * sDepth;
        S.w =  0.0;
        
        let orthoMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return orthoMatrix
    }
    
    func ortho2d(_ origin: simd_float3,
                _ size: simd_float3) -> simd_float4x4
    {
        
        return ortho2d(
            origin.x,
            origin.y,
            origin.z,
            size.x,
            size.y,
            size.z);
    }
}

extension Projection {
    func ortho2dOC(_ left: Float,
                 _ right: Float,
                 _ bottom: Float,
                 _ top: Float,
                 _ near: Float,
                 _ far: Float) -> simd_float4x4
    {
        let sLength: Float = 1.0 / (right - left)
        let sHeight: Float = 1.0 / (top - bottom)
        let sDepth: Float = 1.0 / (far - near)
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = 2.0 * sLength;
        P.y = 0.0;
        P.z = 0.0;
        P.w = 0.0;
        
        Q.x = 0.0;
        Q.y = 2.0 * sHeight;
        Q.z = 0.0;
        Q.w = 0.0;
        
        R.x = 0.0;
        R.y = 0.0;
        R.z = sDepth;
        R.w = 1.0;
        
        S.x = -sLength * (left + right);
        S.y = -sHeight * (top + bottom);
        S.z = -near * sDepth;
        S.w = -sDepth  * near;
        
        let orthoMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return orthoMatrix
    }
    
    func ortho2dOC(_ origin: simd_float3,
                _ size: simd_float3) -> simd_float4x4
    {
        
        return ortho2dOC(
            origin.x,
            origin.y,
            origin.z,
            size.x,
            size.y,
            size.z);
    }
}

extension Projection {
    public static func frustum(_ fovH: Float,
                 _ fovV: Float,
                 _ near: Float,
                 _ far: Float) -> simd_float4x4
    {
        let width: Float  = 1.0 / tan(radians(0.5 * fovH));
        let height: Float = 1.0 / tan(radians(0.5 * fovV));
        let sDepth: Float = far / ( far - near );
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = width;
        P.y = 0.0;
        P.z = 0.0;
        P.w = 0.0;
        
        Q.x = 0.0;
        Q.y = height;
        Q.z = 0.0;
        Q.w = 0.0;
        
        R.x = 0.0;
        R.y = 0.0;
        R.z = sDepth;
        R.w = 1.0;
        
        S.x = 0.0;
        S.y = 0.0;
        S.z = -sDepth * near;
        S.w = 0.0;
        
        let frustMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return frustMatrix
    }
    
    func frustum(_ left: Float,
                 _ right: Float,
                 _ bottom: Float,
                 _ top: Float,
                 _ near: Float,
                 _ far: Float) -> simd_float4x4
    {
        let width: Float = right - left
        let height: Float = top - bottom
        let depth: Float = far - near
        let sDepth: Float = far / depth
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = width;
        P.y = 0.0;
        P.z = 0.0;
        P.w = 0.0;
        
        Q.x = 0.0;
        Q.y = height;
        Q.z = 0.0;
        Q.w = 0.0;
        
        R.x = 0.0;
        R.y = 0.0;
        R.z = sDepth;
        R.w = 1.0;
        
        S.x =  0.0;
        S.y =  0.0;
        S.z = -near * near;
        S.w =  0.0;
        
        let frustMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return frustMatrix
    }
    
    func frustumOC(_ left: Float,
                 _ right: Float,
                 _ bottom: Float,
                 _ top: Float,
                 _ near: Float,
                 _ far: Float) -> simd_float4x4
    {
        let sWidth: Float = 1.0/(right - left)
        let sHeight: Float = 1.0/(top - bottom)
        let sDepth: Float = far / (far - near)
        let dNear: Float = 2.0 * near
        
        var P: simd_float4 = .init();
        var Q: simd_float4 = .init();
        var R: simd_float4 = .init();
        var S: simd_float4 = .init();
        
        P.x = dNear * sWidth;
        P.y = 0.0;
        P.z = 0.0;
        P.w = 0.0;
        
        Q.x = 0.0;
        Q.y = dNear * sHeight;
        Q.z = 0.0;
        Q.w = 0.0;
        
        R.x = -sWidth * (right + left);
        R.y = -sHeight * (top   + bottom);
        R.z = sDepth;
        R.w = 1.0;
        
        S.x =  0.0;
        S.y =  0.0;
        S.z = -sDepth * near;
        S.w =  0.0;
        
        let frustMatrix: simd_float4x4 = .init(P, Q, R, S)
        
        return frustMatrix
    }
}
