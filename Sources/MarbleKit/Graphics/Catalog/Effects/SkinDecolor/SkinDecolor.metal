//
//  SkinDecolor.metal
//  Wonder
//
//  Created by PEXAVC on 3/28/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void SkinDecolorKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& threshold [[ buffer(0) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    
    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
    
    float2 uv = float2(gid);
    uv.x /= widthOrig;
    uv.y /= heightOrig;
    
    float4 color = inTexture.read(gid);
    
    if (threshold == 0) {

        outTexture.write(float4(color.r/4.0, color.g/4.0, color.b/4.0, color.a), gid);
    } else {
        
        outTexture.write(float4(color.r*4.0, color.g*4.0, color.b*4.0, color.a), gid);
    }

}

