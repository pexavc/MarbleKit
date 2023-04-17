//
//  GlitchKernel.metal
//  Wonder
//
//  Created by 0xKala on 8/14/19.
//  Copyright © 2019 0xKala. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;

#define THRESHOLD 0.2

using namespace metal;

float random_2(float2 c){
    return fract(sin(dot(c.xy, float2(12.9898,78.233))) * 43758.5453);
}

float gscale (float3 c) { return (c.r+c.g+c.b)/3.; }

float3 channel_mix_4(float3 a, float3 b, float3 w) {
    return float3(mix(a.r, b.r, w.r), mix(a.g, b.g, w.g), mix(a.b, b.b, w.b));
}

float3 overlay_4(float3 a, float3 b, float w) {
    return mix(a, channel_mix_4(
        2.0 * a * b,
        float3(1.0) - 2.0 * (float3(1.0) - a) * (float3(1.0) - b),
        step(float3(0.5), a)
    ), w);
}

kernel void DriveKernel(texture2d<float, access::sample> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         constant float& iTime [[buffer(0)]],
                         constant float& threshold [[buffer(1)]],
                         constant float& sliderThreshold [[buffer(2)]],
                         uint2 gid [[thread_position_in_grid]]){

    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }

    float w = float(inTexture.get_width());
    float h = float(inTexture.get_height());
//    float2 uv = (float2(gid) * float2(1.0/w, 1.0/h));
    float2 iResolution = float2(w, h);
//    constexpr sampler s(address::repeat, filter::linear, coord::normalized);
    float t = iTime/8.0;
    float2 r = iResolution.xy;
    float2 p=float2(gid);
    
//    float valueThreshold = 1.0;
//    if (threshold > 0.42) {
//        valueThreshold = threshold;
//    }
    float4 k=float4(1,.98,.98, 0);//.9*valueThreshold,.9*valueThreshold,0);
    float2 n=5.*(p+p-r)/r.y;
    n*=3./(.5+n.y); //n*=2 .. old
    n.y-=t*2.;
    
    float brightnessThreshold = threshold*0.57;
    
    n=(.05+brightnessThreshold)/sqrt(abs(fract(n*.4)-.5));
    
    float4 color = inTexture.read(gid);
    float4 c = color + float4(1,.2,0,0)*-(length(p-r/2.)-r.y/4.)*.01+p.y/r.y*k*.8;
//    if(p.y>r.y/2.2)
    c=(n.x+n.y)*k+float4(0,0,0,0);
    
    //This draws the synthwave sun
//    c+=sin(p.y/2.+sin(t)*60.)*.02;
    float4 inColor = inTexture.read(gid);
    float3 finalColor = overlay_4(c.rgb, inColor.rgb, (4*sliderThreshold) + 12.0*threshold);
    outTexture.write(float4(finalColor, inColor.a), gid);

}
