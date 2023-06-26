//
//  PaddedDownsample.metal
//  Marble
//
//  Created by PEXAVC on 8/10/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void PaddedDownsampleKernel(texture2d<half, access::sample> inTexture [[texture(0)]],
                               texture2d<half, access::write> outTexture [[texture(1)]],
                               uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() ||
        gid.y >= outTexture.get_height()) {
        return;
    }
    
    const ushort in_width = inTexture.get_width();
    const ushort in_height = inTexture.get_height();
    
    ushort out_width, out_height;
    float scale;
    
    if(in_width > in_height) {
        scale = float(in_width) / outTexture.get_width();
        
        out_width = outTexture.get_width();
        out_height = ushort(in_height / scale); // <= out_width
        
    } else {
        scale = float(in_height) / outTexture.get_height();
        
        out_height = outTexture.get_height();
        out_width = ushort(in_width / scale); // <= out_height
    }
    
    if (gid.x >= out_width || gid.y >= out_height) {
        outTexture.write(half4(0.0), gid);
    }
    else {
        constexpr sampler s(coord::pixel, filter::linear, address::clamp_to_zero);
        
        const float in_x = gid.x * scale;
        const float in_y = gid.y * scale;
        
        float4 out = float4(inTexture.sample(s, float2(in_x, in_y)));
        outTexture.write(half4(out), gid);
    }
    
}
