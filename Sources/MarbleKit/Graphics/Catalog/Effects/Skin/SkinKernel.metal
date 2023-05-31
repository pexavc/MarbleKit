//
//  SkinKernel.metal
//  Wonder
//
//  Created by PEXAVC on 3/31/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float3 channel_mix_2(float3 a, float3 b, float3 w) {
    return float3(mix(a.r, b.r, w.r), mix(a.g, b.g, w.g), mix(a.b, b.b, w.b));
}

float3 overlay_2(float3 a, float3 b, float w) {
    return mix(a, channel_mix_2(
        2.0 * a * b,
        float3(1.0) - 2.0 * (float3(1.0) - a) * (float3(1.0) - b),
        step(float3(0.5), a)
    ), w);
}

float map(float value, float low1, float high1, float low2, float high2) {
   return low2 + (value - low1) * (high2 - low2) / (high1 - low1);
}

kernel void SkinKernel( texture2d<float, access::sample> inTexture [[ texture(0) ]],
                        texture2d<float, access::sample> skinTexture [[ texture(1) ]],
                        texture2d<float, access::write> outTexture [[ texture(2) ]],
                        constant float& env [[ buffer(0) ]],
                        constant float& threshold [[ buffer(1) ]],
                        constant float& time [[ buffer(2) ]],
                        constant float& skinMode [[ buffer(3) ]],
                        constant float& fill [[ buffer(4) ]],
                        constant float& isRear [[ buffer(5) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
   
    
    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
//
//    float2 texcoord = float2(gid);
//    texcoord.x /= widthOrig;
//    texcoord.y /= heightOrig;
    
    const float timeMulti = 0.2;
    
//    const float xSpeed = 0.12;
    const float ySpeed = 0.12;
    
    float timeNew = time * timeMulti;
    
    float2 fragCoord;
    if (env == 1.0) {
        fragCoord = float2(gid.x, heightOrig - gid.y);
    } else {
        fragCoord = float2(gid.x, gid.y);
    }
    float2 res = float2(widthOrig, heightOrig);
    // no floor makes it squiqqly
    float xCoord = floor(fragCoord.x);// + timeNew * xSpeed * res.x);
    float yCoord = floor(fragCoord.y + timeNew * ySpeed * res.y);
    
    float2 coor = float2(xCoord, yCoord);
    coor = fmod(coor, res);
    
    float2 uv;
    
    if (skinMode == 1.0 && fill == 0.0) {
        uv = fragCoord/res;;
    } else {
        uv = coor/res.xy;
    }
    // Time varying pixel color
    //vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    float4 skinColor = skinTexture.sample(s, uv);

    
    float4 inColor;
    
    if (skinMode == 1.0) {
        inColor = inTexture.read(gid);
        if (inColor.a == 0.0) {
            
            outTexture.write(mix(float4(0.0, 0.0, 0.0, 1.0), skinColor, 0.75), gid);
        } else {
            if (fill == 1.0) {
                inColor = inTexture.sample(s, uv);
            }
            

            outTexture.write(inColor, gid);
        }
    } else {
        if (env == 1.0 && isRear == 0.0) {
            inColor = inTexture.read(uint2(uint(widthOrig) - gid.x, gid.y));
        } else {
            if (env == 0.0) {
                inColor = inTexture.read(uint2(gid.x, uint(heightOrig) - gid.y));
            } else {
                inColor = inTexture.read(gid);
            }
        }
        float val = (threshold);

        if (val < 0.12) {
            val = 0.066;
        }
        float3 finalColor = overlay_2(skinColor.rgb, inColor.rgb, 12*val);
        outTexture.write(float4(finalColor, inColor.a), gid);
    }
    
    
}


