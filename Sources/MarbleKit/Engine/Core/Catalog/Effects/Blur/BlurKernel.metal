//
//  BokehKernel.metal
//  Wonder
//
//  Created by PEXAVC on 1/10/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//
// https://www.shadertoy.com/view/Xltfzj

#include <metal_stdlib>
using namespace metal;

kernel void BlurKernel(texture2d<float, access::sample> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         constant float& time [[buffer(0)]],
                         constant float& threshold [[buffer(1)]],//radius
                         uint2 gid [[thread_position_in_grid]]){
    
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    
    constexpr sampler s(address::repeat, filter::linear, coord::normalized);
    
    float w = float(inTexture.get_width());
    float h = float(inTexture.get_height());
    float2 uv = float2(gid) * float2(1.0/w, 1.0/h);
    
    float Pi = 6.28318530718; // Pi*2
    float Directions = 16.0;
    float Quality = 3.0;
    float Size = threshold;
    
    float2 Radius = Size/float2(gid);
    float4 col = inTexture.sample(s, uv);
    for( float d=0.0; d<Pi; d+=Pi/Directions)
    {
        for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
        {
            if (threshold < 0) {
                col += inTexture.sample(s, uv+float2(acos(d),asin(d))*(-1*Radius)*i);
            } else {
                col += inTexture.sample(s, uv+float2(cos(d),sin(d))*Radius*i);
            }
        }
    }
    //

    col /= Quality * Directions - 15.0;
    outTexture.write(col, gid);
}


