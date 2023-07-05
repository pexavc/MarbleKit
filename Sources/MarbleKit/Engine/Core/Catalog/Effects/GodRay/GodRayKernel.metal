//
//  BlurKernel.metal
//  Wonder
//
//  Created by PEXAVC on 3/28/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;

// Radial blur samples. More is always better, but there's frame rate to consider.



// 2x1 hash. Used to jitter the samples.
float hash( float2 p ){ return fract(sin(dot(p, float2(41, 289)))*45758.5453); }


// Light offset.
//
// I realized, after a while, that determining the correct light position doesn't help, since
// radial blur doesn't really look right unless its focus point is within the screen boundaries,
// whereas the light is often out of frame. Therefore, I decided to go for something that at
// least gives the feel of following the light. In this case, I normalized the light position
// and rotated it in unison with the camera rotation. Hacky, for sure, but who's checking? :)
float3 lOff(float iTime){
    
    float2 u = sin(float2(1.57, 0) - iTime/2.);
    float2x2 a = float2x2(u.x, u.y, -u.y, u.x);
    
    float3 l = normalize(float3(1.5, 1., -0.5));
    l.xz = a * l.xz;
    l.xy = a * l.xy;
    
    return l;
    
}

kernel void GodRayKernel(texture2d<float, access::sample> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& threshold [[ buffer(0) ]],
                        constant float& time [[ buffer(1) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    float4 inColor = inTexture.read(gid);
    
    float d = sqrt(pow((255-(inColor.r*255.0)), 2)+pow((255-(inColor.g*255.0)), 2)+pow((255-(inColor.b*255.0)),2));
    float p=d/sqrt(pow(255.0, 2.0)+pow(255.0, 2.0)+pow(255.0, 2.0));
    
    if (p < 0.42) {
        outTexture.write( inColor, gid);
    } else {
        
    
    
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    const float SAMPLES = 24.0;
    
    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
    
    float2 uv = float2(gid);
    uv.x /= widthOrig;
    uv.y /= heightOrig;
    
    // Radial blur factors.
    //
    // Falloff, as we radiate outwards.
    float decay = 0.84;
    // Controls the sample density, which in turn, controls the sample spread.
    float density =/* 0.75**/(threshold);
    // Sample weight. Decays as we radiate outwards.
    float weight = 0.1;
    
    // Light offset. Kind of fake. See above.
    float3 l = lOff(1047552.56);
    
    // Offset texture position (uv - .5), offset again by the fake light movement.
    // It's used to set the blur direction (a direction vector of sorts), and is used
    // later to center the spotlight.
    //
    // The range is centered on zero, which allows the accumulation to spread out in
    // all directions. Ie; It's radial.
    float2 tuv =  uv - .5 - l.xy*.45;
    
    // Dividing the direction vector above by the sample number and a density factor
    // which controls how far the blur spreads out. Higher density means a greater
    // blur radius.
    float2 dTuv = tuv*density/SAMPLES;
    
    // Grabbing a portion of the initial texture sample. Higher numbers will make the
    // scene a little clearer, but I'm going for a bit of abstraction.
    float4 col = inTexture.sample(textureSampler, uv)*0.25;
    
    // Jittering, to get rid of banding. Vitally important when accumulating discontinuous
    // samples, especially when only a few layers are being used.
    uv += dTuv*(hash(uv.xy + fract(1047552.56))*2. - 1.);
    
    // The radial blur loop. Take a texture sample, move a little in the direction of
    // the radial direction vector (dTuv) then take another, slightly less weighted,
    // sample, add it to the total, then repeat the process until done.
    for(float i=0.; i < 4; i++){
    
        uv -= dTuv;
        
        
//        float4 s = inTexture.sample(textureSampler, uv);
//        col += smoothstep(0.75, 0.85, length(s.xyz)) * s * weight;
        
        col += inTexture.sample(textureSampler, uv) * weight;
        
        weight *= decay;
        
    }
    
    // Multiplying the final color with a spotlight centered on the focal point of the radial
    // blur. It's a nice finishing touch... that Passion came up with. If it's a good idea,
    // it didn't come from me. :)
    col *= (1. - dot(tuv, tuv)*.75);
    
    // Smoothstepping the final color, just to bring it out a bit, then applying some
    // loose gamma correction.
    
    // Bypassing the radial blur to show the raymarched scene on its own.
    //fragColor = sqrt(texture(iChannel0, fragCoord.xy / iResolution.xy));
    
    
    outTexture.write( sqrt(smoothstep(0., 1., col)), gid);
        
    }
}

