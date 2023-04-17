//
//  BackdropKernel.metal
//  Wonder
//
//  Created by 0xKala on 8/17/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void BackdropKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
                        texture2d<float, access::read> backdropTexture [[ texture(1) ]],
                        texture2d<float, access::write> outTexture [[texture(2)]],
                        constant float& opacity [[ buffer(0) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    
//    float widthOrig = inTexture.get_width();
//    float heightOrig = inTexture.get_height();
//    
//    float widthBackdrop = backdropTexture.get_width();
//    float heightBackdrop = backdropTexture.get_height();
//    
//    float offsetX = (widthBackdrop - widthOrig)/2;
//    float offsetY = (heightBackdrop - heightOrig)/2;
//
//    float2 ngid = float2(gid);
//    ngid.x /= widthOrig;
//    ngid.y /= heightOrig;
    
//    constexpr sampler s(address::repeat, filter::linear, coord::normalized);
    
    float4 orig = inTexture.read(gid);
    float4 backdropColor = backdropTexture.read(gid);//uint2(gid.x + uint(offsetX), gid.y + uint(offsetY)));
    float4 backdropColorMixed = mix(float4(0.0, 0.0, 0.0, 1.0), backdropColor, opacity);
    if (orig.a == 0.0) {
        outTexture.write(backdropColorMixed, gid);
    } else {
        outTexture.write(orig, gid);
    }
}

