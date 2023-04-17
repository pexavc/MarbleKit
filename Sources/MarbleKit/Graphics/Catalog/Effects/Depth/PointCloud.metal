//
//  PointCloud.metal
//  Marble
//
//  Created by 0xKala on 8/9/20.
//  Copyright © 2020 Linen & Sole. All rights reserved.
//

#include <metal_stdlib>
#import "../../../Metal/Loki/loki_header.metal"
using namespace metal;

float2 rotate(float2 input, float angle)
{
    float c = cos(angle * (M_PI_F/180.0f));
    float s = sin(angle * (M_PI_F/180.0f));
    return float2(
        input.x * c - input.y * s,
        input.x * s + input.y * c);
}

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 coor;
    float pSize [[point_size]];
    float depth;
    float4 color;
} RasterizerDataColor;

// Vertex Function
vertex RasterizerDataColor
vertexShaderPoints(uint vertexID [[ vertex_id ]],
                   texture2d<float, access::read> depthTexture [[ texture(0) ]],
                   constant float4x4& viewMatrix [[ buffer(0) ]],
                   constant float& threshold [[ buffer(1) ]],
                   constant float& isLandscape [[ buffer(2) ]],
                   constant float& skinMode [[ buffer(3) ]],
                   constant float& scale [[ buffer(4) ]],
                   constant float& width [[ buffer(5) ]],
                   constant float& height [[ buffer(6) ]])
{
    RasterizerDataColor out;
    
    uint widthDepth = uint(depthTexture.get_width());
    uint heightDepth = uint(depthTexture.get_height());
    
    uint2 pos;
    float depth;
    
    pos.y = vertexID / depthTexture.get_width();
    pos.x = vertexID % depthTexture.get_width();
    
    float realDepth = depthTexture.read(pos).x;
    depth = min(1.0 - realDepth, 1.0);
    
//
//    // When using Loki, it's as simple as just calling rand()!
//    float random_float = loki.rand();
    
    //0.48 works well for some
    //0.09 - 0.12 // 0.16
    if (realDepth > 0.16) {
        depth = depth * 600;
    } else {
        depth = -1;
    }
    
    //The 48.0 is adjusted intrinsic, but from the iPhone 11 itself
    //it should be 13.2 a 3.63 downscale is brought here due to depth
    //map resolution
  
    /**
     
     float xrw = (pos.y - (2200.383/12.0)) * depth / (6329.063/12.0);
     float yrw = (pos.x - (3200.9828/12.0)) * depth / (6329.063/12.0);
     
            /// The (pos.y - (2200.383/12.0)) and (pos.x - (3200.9828/12.0))
                        // The 2200 && 3200 should be the aspect ratio
                        // of the drawable size
     */
    
    //(4800.652, 6400.063) == Landscape If the dividend is 12
    //so '6400/12`
    
    /**
        the equations below can be read as
            -> `x = (y - (s) * (d / c))`
            -> `y = (x - (s) * (d / c))`
            
                    s = (dimensional size / position_scale)
                    position_scale =  (6400 / 5.33
                    
                
     */
    float xrw = (pos.y - (height/2)) * depth / (6329.063/12.0);
    float yrw = (pos.x - (width/2)) * depth / (6329.063/12.0);
    
    float4 xyzw = { xrw, yrw, depth, 1.f };
    
    out.clipSpacePosition = (viewMatrix * xyzw);
    
    out.coor = {
        float(pos.x) / (depthTexture.get_width()),
        float(pos.y) / (depthTexture.get_height()) };
    
    out.depth = depth;
//    if (scale > 0.0) {
//        out.pSize = 0.36;// + scale/116;
//    } else {
//        out.pSize = 0.24;
//    }
    
    out.pSize = 1.2;//1.36;//1.36;
    
    return out;
}

fragment float4 fragmentShaderPoints(RasterizerDataColor in [[stage_in]],
                                     texture2d<float> colorTexture [[ texture(0) ]],
                                     texture2d<float> skinTexture [[ texture(1) ]],
                                     constant float& threshold [[ buffer(0) ]],
                                     constant float& isLandscape [[ buffer(1) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    float2 fGid = float2(in.coor.xy);
    float2 size = float2(colorTexture.get_width(), colorTexture.get_height());
    float2 fGid_e = float2(fGid.x*size.x, fGid.y*size.y);
    //175 - 250
    //160 - 175 isolation
    if (in.depth < 0) {//} || (fGid_e.x < 12.0 || fGid_e.y < 12.0 || fGid_e.x > size.x - 12 || fGid_e.y > size.y - 12)) {//} || in.depth < threshold){
//        discard_fragment();
        //masking purposes
        //
        return float4(0.0);
    }else
    {
        
        float4 colorSample = colorTexture.sample (textureSampler, fGid);
        
        
        return colorSample;
        
    }
}

