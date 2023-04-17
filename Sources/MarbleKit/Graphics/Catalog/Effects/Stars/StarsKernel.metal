//
//  StarsKernel.metal
//  Wonder
//
//  Created by 0xKala on 4/22/20.
//  Copyright © 2020 0xKala. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float field( float3 p,float s, float iTime, float threshold) {
    float strength = 7. + .03 * log(1.e-6 + fract(sin(iTime) * 4373.11));
    float accum = s/4.;
    float prev = 0.;
    float tw = 0.;
    for (int i = 0; i < 24; ++i) {
        float mag = dot(p, p);
        p = abs(p) / mag + float3(-.5, -.4, -1.5);
        float w = exp(-float(i) / 7.);//8. - (1.5*threshold));
        accum += w * exp(-strength * pow(abs(mag - prev), 2.2));
        tw += w;
        prev = mag;
    }
    return max(0., 5. * accum / tw - .7);
}

// Less iterations for second layer
float field2( float3 p, float s, float iTime) {
    float strength = 7. + .03 * log(1.e-6 + fract(sin(iTime) * 4373.11));
    float accum = s/4.;
    float prev = 0.;
    float tw = 0.;
    for (int i = 0; i < 12; ++i) {
        float mag = dot(p, p);
        p = abs(p) / mag + float3(-.5, -.4, -1.5);
        float w = exp(-float(i) / 7.);
        accum += w * exp(-strength * pow(abs(mag - prev), 2.2));
        tw += w;
        prev = mag;
    }
    return max(0., 5. * accum / tw - .7);
}

float3 nrand3( float2 co )
{
    float3 a = fract( cos( co.x*8.3e-3 + co.y )*float3(1.3e5, 4.7e5, 2.9e5) );
    float3 b = fract( sin( co.x*0.3e-3 + co.y )*float3(8.1e5, 1.0e5, 0.1e5) );
    float3 c = mix(a, b, 0.5);
    return c;
}

float3 channel_mix_3(float3 a, float3 b, float3 w) {
    return float3(mix(a.r, b.r, w.r), mix(a.g, b.g, w.g), mix(a.b, b.b, w.b));
}

float3 overlay_3(float3 a, float3 b, float w) {
    return mix(a, channel_mix_3(
        2.0 * a * b,
        float3(1.0) - 2.0 * (float3(1.0) - a) * (float3(1.0) - b),
        step(float3(0.5), a)
    ), w);
}

kernel void StarsKernel(texture2d<float, access::sample> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& iTime [[ buffer(0) ]],
                        constant float& threshold [[ buffer(1) ]],
                        constant float& sliderThreshold [[ buffer(2) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    // This assists depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a != 0.0) {
        outTexture.write(inTexture.read(gid), gid);
        return;
    }
    constexpr sampler s (mag_filter::linear, min_filter::linear);

    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
    
    float2 iResolution = float2(widthOrig, heightOrig);
//    float2 uv = float2(gid.x, gid.y) / float2(widthOrig, heightOrig);
    float2 fragCoord = float2(gid.x, gid.y);

    
    float2 uv = 2. * fragCoord.xy / iResolution.xy - 1.;
    float2 uvs = uv * iResolution.xy / max(iResolution.x, iResolution.y);
    float3 p = float3(uvs / 4., 0) + float3(1., -1.3, 0.);
    p += .2 * float3(sin(iTime / 16.), sin(iTime / 12.),  sin(iTime / 128.));

    float freqs[4];
    //Sound
    freqs[0] = threshold*0.36;// inTexture.sample( s, float2( 0.01, 0.25 ) ).x;
    freqs[1] = threshold*0.48;//inTexture.sample( s, float2( 0.07, 0.25 ) ).x;
    freqs[2] = threshold*0.75;//inTexture.sample( s, float2( 0.15, 0.25 ) ).x;
    freqs[3] = threshold*0.93;//inTexture.sample( s, float2( 0.30, 0.25 ) ).x;

    float t = field(p,freqs[2], iTime, threshold);
    float v = (1. - exp((abs(uv.x) - 1.) * 6.)) * (1. - exp((abs(uv.y) - 1.) * 6.));

    //Second Layer
    float3 p2 = float3(uvs / (4.+sin(iTime*0.11)*0.2+0.2+sin(iTime*0.15)*0.3+0.4), 1.5) + float3(2., -1.3, -1.);
    p2 += 0.25 * float3(sin(iTime / 16.), sin(iTime / 12.),  sin(iTime / 128.));
    float t2 = field2(p2,freqs[3], iTime);
    float4 c2 = mix(.4, 1., v) * float4(1.3 * t2 * t2 * t2 ,1.8  * t2 * t2 , t2* freqs[0], t2);


    //Let's add some stars
    //Thanks to http://glsl.heroku.com/e#6904.0
    float2 seed = p.xy * 2.0;
    seed = floor(seed * iResolution.x);
    float3 rnd = nrand3( seed );
    float4 starcolor = float4(pow(rnd.y,20.0));//40.0));

    //Second Layer
    float2 seed2 = p2.xy * 2.0;
    seed2 = floor(seed2 * iResolution.x);
    float3 rnd2 = nrand3( seed2 );
    starcolor += float4(pow(rnd2.y,40.0));
    
    //third Layer
//    float2 seed3 = p2.xy * 2.0;
//    seed3 = floor(seed3 * iResolution.x);
//    float3 rnd3 = nrand3( seed3 );
//    starcolor += float4(pow(rnd3.y,40.0));
////
//    //fourth Layer
//    float2 seed4 = p2.xy * 2.0;
//    seed4 = floor(seed4 * iResolution.x);
//    float3 rand4 = nrand3( seed4 );
//    starcolor += float4(pow(rand4.y,40.0));

    float4 color = mix(freqs[3]-.3, 1., v) * float4(1.5*freqs[2] * t * t* t , 1.2*freqs[1] * t * t, freqs[3]*t, 1.0)+c2+starcolor;
    
    float4 inColor = inTexture.read(gid);
    float3 finalColor = overlay_3(color.rgb, inColor.rgb, (4*sliderThreshold) + 12*threshold);
    outTexture.write(float4(finalColor, inColor.a), gid);
}


