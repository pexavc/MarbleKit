//
//  DepthKernel.metal
//  Wonder
//
//  Created by PEXAVC on 1/2/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//
#define POINT_SCALE 5.0
#define SIGHT_RANGE 150.0

#include <metal_stdlib>
using namespace metal;

kernel void DepthKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
                        texture2d<float, access::read> depthTexture [[ texture(1) ]],
                        texture2d<float, access::write> outTexture [[ texture(2) ]],
                        constant float& depthOfCenter [[ buffer(0) ]],
                        constant float& threshold [[ buffer(1) ]],
                        constant float& rear [[ buffer(2) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    
    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
    
    uint widthDepth = uint(depthTexture.get_width());
    uint heightDepth = uint(depthTexture.get_height());
    
    float2 ngid = float2(gid);
    ngid.x /= widthOrig;
    ngid.y /= heightOrig;
    
    float4 orig = inTexture.read(gid);
    float4 depth;
    
    if (rear == 1.0) {
        depth = depthTexture.read(uint2(widthDepth - (gid.y), heightDepth - (gid.x)));
    } else {
        depth = depthTexture.read(uint2(widthDepth - (gid.y), (gid.x)));
    }
    
    float dist = distance(float2(0.5), ngid);
    float intensity = (1.0 - (dist * 2.0));
    
    outTexture.write(float4((depth.x / 1000.0) * intensity, (depth.y / 1000.0) * intensity, (depth.z / 1.0) * intensity, intensity), gid);
//
//    float depthSum = ((depth.r + depth.g + depth.b + depth.a)/4) * 4;
//    if (depthSum < 0) {
//        depthSum = 0;
//    }
//
//    if (depthSum > depthOfCenter - 0.25) {//1.65) {
//        outTexture.write(float4(orig.r, orig.g, orig.b, (depthSum/4.0)), gid);
//    } else {
//        outTexture.write(orig, gid);
//    }
}
