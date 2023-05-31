//
//  AnalogKernel.metal
//  Wonder
//
//  Created by PEXAVC on 1/10/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float3 channel_mix(float3 a, float3 b, float3 w) {
    return float3(mix(a.r, b.r, w.r), mix(a.g, b.g, w.g), mix(a.b, b.b, w.b));
}

float gaussian(float z, float u, float o) {
    return (1.0 / (o * sqrt(2.0 * 3.1415))) * exp(-(((z - u) * (z - u)) / (2.0 * (o * o))));
}

float3 madd(float3 a, float3 b, float w) {
    return a + a * b * w;
}

float3 screen(float3 a, float3 b, float w) {
    return mix(a, float3(1.0) - (float3(1.0) - a) * (float3(1.0) - b), w);
}

float3 overlay(float3 a, float3 b, float w) {
    return mix(a, channel_mix(
        2.0 * a * b,
        float3(1.0) - 2.0 * (float3(1.0) - a) * (float3(1.0) - b),
        step(float3(0.5), a)
    ), w);
}

float3 soft_light(float3 a, float3 b, float w) {
    return mix(a, pow(a, pow(float3(2.0), 2.0 * (float3(0.5) - b))), w);
}

float4x4 brightnessMatrix( float brightness )
{
    return float4x4( 1, 0, 0, 0,
                 0, 1, 0, 0,
                 0, 0, 1, 0,
                 brightness, brightness, brightness, 1 );
}

float4x4 contrastMatrix( float contrast )
{
    float t = ( 1.0 - contrast ) / 2.0;
    
    return float4x4( contrast, 0, 0, 0,
                 0, contrast, 0, 0,
                 0, 0, contrast, 0,
                 t, t, t, 1 );

}

float4x4 saturationMatrix( float saturation )
{
    float3 luminance = float3( 0.3086, 0.6094, 0.0820 );
    
    float oneMinusSat = 1.0 - saturation;
    
    float3 red = float3( luminance.x * oneMinusSat );
    red+= float3( saturation, 0, 0 );
    
    float3 green = float3( luminance.y * oneMinusSat );
    green += float3( 0, saturation, 0 );
    
    float3 blue = float3( luminance.z * oneMinusSat );
    blue += float3( 0, 0, saturation );
    
    return float4x4(red.r, red.g, red.b, 0,
                 green.r, green.g, green.b, 0,
                 blue.r, blue.g, blue.b, 0,
                 0, 0, 0, 1 );
}

kernel void AnalogKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& threshold [[ buffer(0) ]],
                        constant float& type [[ buffer(1) ]],
                        constant float& time [[ buffer(2) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    
//    constexpr sampler s(address::repeat, filter::linear, coord::normalized);
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    
    float SPEED = 2.0; // 2.0
    float MEAN = 0.0; //0.0
    float VARIANCE = 0.5;
    float INTENSITY = threshold; //Assuming threshold is [0.0, 1.0]

    if (type == 1.0) {
        INTENSITY *= 0.12;
    } else if (type == 2.0) {
        INTENSITY *= 0.12;
    } else if (type == 3.0) {
        INTENSITY *= 0.2;
    } else if (type == 4.0) {
        INTENSITY = 0.24;
    }
    
    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();

    float2 ngid = float2(gid);
    ngid.x /= widthOrig;
    ngid.y /= heightOrig;

    float4 color = inTexture.read(gid);
    
    color = pow(color, float4(2.2));
    
    float t = time * float(SPEED);
    float seed = dot(ngid, float2(12.9898, 78.233));
    float noise = fract(sin(seed) * 43758.5453 + t);
    noise = gaussian(noise, float(MEAN), float(VARIANCE) * float(VARIANCE));

    float3 grain = float3(noise) * (1.0 - color.rgb);

    if (type == 1.0) {
        color.rgb = max(color.rgb, grain * INTENSITY);// grain * INTENSITY;
    } else if (type == 2.0) {
        color.rgb = screen(color.rgb, grain, INTENSITY);
    } else if (type == 3.0) {
        color.rgb = soft_light(color.rgb, grain, INTENSITY);
    } else if (type == 4.0) {
        color.rgb = overlay(color.rgb, grain, INTENSITY);
    }
    
    color = pow(color, float4(1.0 / 2.2));
    
    float brightness = 0.15;
    float contrast = 1.2;
    float saturation = 1.5;
    
    if (type == 1.0) {
        contrast = 1.6;
    } else if (type == 2.0) {
        saturation = 1.5*threshold;
    } else if (type == 3.0) {
        saturation = 2.4;
        contrast = 1.0;
    } else if (type == 4.0) {
        contrast = 1.6*threshold;
        brightness = 0.12;
    }
    
    color = brightnessMatrix( brightness ) *
    contrastMatrix( contrast ) *
    saturationMatrix( saturation ) *
    color;
    
    outTexture.write(float4(color.rgb, inTexture.read(gid).a), gid);
}
