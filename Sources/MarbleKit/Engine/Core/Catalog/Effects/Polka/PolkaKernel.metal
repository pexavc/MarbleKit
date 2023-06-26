//
//  MetallicKernel.metal
//  Wonder
//
//  Created by PEXAVC on 4/19/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void PolkaKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& time [[ buffer(0) ]],
                        constant float& threshold [[ buffer(1) ]],
                        constant float& sliderThreshold [[ buffer(2) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    

//    float widthOrig = inTexture.get_width();
//    float heightOrig = inTexture.get_height();
    
//    float2 uv = float2(gid.x, gid.y) / float2(widthOrig, heightOrig);
    float2 fGid = float2(gid.x, gid.y);
//    float2 res = float2(widthOrig, heightOrig);

    float thickness = 4;//16 + (threshold*8);
    float2 C = ceil(fGid/thickness)*thickness - (thickness/2);
    float4 O = inTexture.read(uint2(C));
    //float4(.2, .7, .07, 0) was OG
    //O *= smoothstep(8.,4., length(fGid-C)/max(.1, dot(O, float4(.5, .7, .07, 0))));
    O *= smoothstep(8.,4., length(fGid-C)/max(.1, dot(O, float4(.2, .12, .07, 0))));
    
    outTexture.write(O, gid);

    //OG
    //
//    vec2 center = floor(fragCoord/16.0)*16.0 + 8.0;
//    vec3 col = texture(iChannel0, center/iResolution.xy).rgb;
//    float l = max(0.1, dot(col, vec3(0.2125, 0.7154, 0.0721)));
//    float dist = distance(center,fragCoord)/8.0;
//    float alpha = smoothstep(1.0, 0.5, dist/l);
    
}


