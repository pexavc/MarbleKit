//
//  Transform.metal
//  Wonder
//
//  Created by 0xKala on 8/13/19.
//  Copyright © 2019 0xKala. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    packed_float2 position;
    packed_float2 texcoord;
} POVertexIn;

struct POVertexOut {
    float4 position [[position]];
    float2 texcoord;
};

vertex POVertexOut TransformVertex(constant POVertexIn *vertices [[buffer(0)]],
                                   uint vid [[vertex_id]]) {
    POVertexOut out;
    POVertexIn v = vertices[vid];
    float2 position = float2(v.position);
    out.position = float4(position.x, position.y, 0.0, 1.0);
    out.texcoord = float2(v.texcoord);
    
    return out;
}

fragment half4 TransformFragment(POVertexOut in [[stage_in]],
                                 texture2d<half, access::read> texture [[texture(0)]]) {
    float2 coords = in.texcoord * float2(texture.get_width(), texture.get_height());
    
    half3 rgb = texture.read(uint2(coords)).rgb;
    return half4(rgb, 1.0);
}
