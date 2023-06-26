//
//  HueKernel.metal
//  Wonder
//
//  Created by PEXAVC on 4/25/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;

float3 channel_mix_5(float3 a, float3 b, float3 w) {
    return float3(mix(a.r, b.r, w.r), mix(a.g, b.g, w.g), mix(a.b, b.b, w.b));
}

float3 overlay_5(float3 a, float3 b, float w) {
    return mix(a, channel_mix_5(
        2.0 * a * b,
        float3(1.0) - 2.0 * (float3(1.0) - a) * (float3(1.0) - b),
        step(float3(0.5), a)
    ), w);
}

kernel void DiscoKernel(texture2d<float, access::sample> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& threshold [[ buffer(0) ]],
                        constant float& sliderThreshold [[ buffer(1) ]],
                        constant float& iTime [[ buffer(2) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    
    constexpr sampler s (mag_filter::linear, min_filter::linear);

    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
    
    float2 iResolution = float2(widthOrig, heightOrig);
    float2 fragCoord = float2(gid.x, gid.y);
    float2 uv = fragCoord / iResolution;
    
    float thresholdAdj1 = 4 + 12*threshold;
    float thresholdAdj2 = 7.0*threshold;
    float3 col = 0.5 + 0.25*(cos(uv.yxy*thresholdAdj1+iTime+uv.xyx*float3(-3,-7,11)*thresholdAdj2) + cos(uv.yxy*(-3.0)+iTime*float3(-11,5,9)*0.3));
    float a = col.x*col.y*col.z;
    float3 b = (1.0-uv.y) * float3(1.0,0.5,0.7) + uv.y * float3(0.4,0.8,1.0);

    float4 color = float4(b * (1.0-(col * a * 5.0)),1.0);
    
    float4 inColor = inTexture.read(gid);
    float3 finalColor = overlay_5(color.rgb, inColor.rgb, (4*sliderThreshold) + 12*threshold);
    outTexture.write(float4(finalColor, inColor.a), gid);
}




