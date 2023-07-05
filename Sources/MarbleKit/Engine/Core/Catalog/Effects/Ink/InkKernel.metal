//
//  InkKernel.metal
//  Wonder
//
//  Created by PEXAVC on 8/14/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float GetTexture(float x, float y, float2 size, texture2d<float, access::sample> inTexture, sampler s) {
    return inTexture.sample(s, float2(x, y)*size).x;
}

kernel void InkKernel(texture2d<float, access::sample> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         constant float& threshold [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]){
    
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    
    float w = float(inTexture.get_width());
    float h = float(inTexture.get_height());
    float2 uv = float2(gid) * float2(1.0/w, 1.0/h);
    constexpr sampler s(address::repeat, filter::linear, coord::normalized);
    
    float x = float(gid.x);//uv.x;
    float y = float(gid.y);//uv.y;
    float2 iRes = float2(1.0/w, 1.0/h);
    
    float xValue = -GetTexture(x-1.0, y-1.0, iRes, inTexture, s) - 2.0*GetTexture(x-1.0, y, iRes, inTexture, s) - GetTexture(x-1.0, y+1.0, iRes, inTexture, s) + GetTexture(x+1.0, y-1.0, iRes, inTexture, s) + 2.0*GetTexture(x+1.0, y, iRes, inTexture, s) + GetTexture(x+1.0, y+1.0, iRes, inTexture, s);
    float yValue = GetTexture(x-1.0, y-1.0, iRes, inTexture, s) + 2.0*GetTexture(x, y-1.0, iRes, inTexture, s) + GetTexture(x+1.0, y-1.0, iRes, inTexture, s) - GetTexture(x-1.0, y+1.0, iRes, inTexture, s) - 2.0*GetTexture(x, y+1.0, iRes, inTexture, s) - GetTexture(x+1.0, y+1.0, iRes, inTexture, s);
    
    if(length(float2(xValue, yValue)) > threshold)
    {
        outTexture.write(float4(0.75), gid);
    }
    else
    {
        outTexture.write(inTexture.sample(s, uv), gid);
    }
}

//float threshold = iMouse.x / iResolution.x;
//
//if(iMouse.x == 0.0) // Browse preview
//{
//    threshold = 0.2;
//}
//
//float x = fragCoord.x;
//float y = fragCoord.y;
//
//float xValue = -GetTexture(x-1.0, y-1.0) - 2.0*GetTexture(x-1.0, y) - GetTexture(x-1.0, y+1.0)
//+ GetTexture(x+1.0, y-1.0) + 2.0*GetTexture(x+1.0, y) + GetTexture(x+1.0, y+1.0);
//float yValue = GetTexture(x-1.0, y-1.0) + 2.0*GetTexture(x, y-1.0) + GetTexture(x+1.0, y-1.0)
//- GetTexture(x-1.0, y+1.0) - 2.0*GetTexture(x, y+1.0) - GetTexture(x+1.0, y+1.0);
//
//if(length(vec2(xValue, yValue)) > threshold)
//{
//    fragColor = vec4(0);
//}
//else
//{
//    vec2 uv = vec2(x, y) / iResolution.xy;
//    vec4 currentPixel = texture(iChannel0, uv);
//    fragColor = currentPixel;
//    }
