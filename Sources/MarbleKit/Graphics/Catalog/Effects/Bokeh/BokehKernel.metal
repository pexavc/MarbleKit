//
//  BokehKernel.metal
//  Wonder
//
//  Created by 0xKala on 1/10/20.
//  Copyright © 2020 0xKala. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void BokehKernel(texture2d<float, access::sample> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         constant float& time [[buffer(0)]],
                         constant float& threshold [[buffer(1)]],
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
    
    float ITERATIONS = 12;
    float GOLDEN_ANGLE = 2.39996;

    float radius = 4*threshold;

    float2x2 rot = float2x2(cos(GOLDEN_ANGLE), sin(GOLDEN_ANGLE), -sin(GOLDEN_ANGLE), cos(GOLDEN_ANGLE));

    float2 vangle = float2(0.0, radius*.01 / sqrt(float(ITERATIONS)));

    float r = 1.;

    float3 acc = float3(0), div = acc;

    for (int j = 0; j < ITERATIONS; j++)
    {
        // the approx increase in the scale of sqrt(0, 1, 2, 3...)
        r += 1. / r;
        vangle = rot * vangle;
        float3 col = inTexture.sample(s, uv + (r-1.) * vangle).xyz;
         /// ... Sample the image
        col = col * col *1.8; // ... Contrast it for better highlights - leave this out elsewhere.
        float3 bokeh = pow(col, float3(4));
        acc += col * bokeh;
        div += bokeh;
    }
    //

    outTexture.write(float4(acc / div,1.0), gid);
}


