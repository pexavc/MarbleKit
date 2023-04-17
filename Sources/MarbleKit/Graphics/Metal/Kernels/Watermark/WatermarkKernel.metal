//
//  WatermarkKernel.metal
//  Wonder
//
//  Created by 0xKala on 8/18/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


kernel void WatermarkKernel(texture2d<float, access::sample> inTexture [[texture(0)]],
                            texture2d<float, access::sample> watermarkTexture [[texture(1)]],
                            texture2d<float, access::write> outTexture [[texture(2)]],
                            constant float2& offset [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    
    float w = outTexture.get_width();
    float h = outTexture.get_height();
    float2 uv = float2(gid) * float2(1.0/w, 1.0/h);
    float2 uvOffsetW = offset * float2(1.0/w, 1.0/h);
    
    float4 color = inTexture.sample(s, uv);
    
    float watermarkWidth = watermarkTexture.get_width();
    float watermarkHeight = watermarkTexture.get_height();
    
    if (uv.x >= uvOffsetW.x && uv.y > uvOffsetW.y && float(gid.x) - offset.x < watermarkWidth - 2 && float(gid.y) - offset.y < watermarkHeight - 2) {
        float4 wColor = watermarkTexture.read(gid - uint2(offset));//sample(s, uv - uvOffsetW);//mix(watermarkTexture.sample(s, uv - uvOffsetW), color, 1.0);
        
        color = wColor;
//        if (wColor.a <= 0.18) {
//            color = wColor;
//        }
    }
    
    outTexture.write(color, gid);
}
