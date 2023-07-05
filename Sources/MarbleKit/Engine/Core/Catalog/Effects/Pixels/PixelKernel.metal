//
//  PixelKernel.metal
//  Wonder
//
//  Created by PEXAVC on 4/25/20.
//  Copyright © 2020 PEXAVC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void PixelKernel(texture2d<float, access::sample> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& threshold [[ buffer(0) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    
    constexpr sampler s (mag_filter::linear, min_filter::linear);

    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
    
    float2 iResolution = float2(widthOrig, heightOrig);
    float2 fragCoord = float2(gid.x, gid.y);
    float2 diffFragCoordXY = fragCoord.xy;
    float2 uv = fragCoord / iResolution;
    float2 uv2 = uv;
    
    float numPixelGrouping = 16.0*threshold;
    
    float4 fragColorAtCoord = inTexture.sample(s, uv);
    
    float4 currentColor = float4(0.0, 0.0, 0.0, 1.0);
    
    if (numPixelGrouping <= 0.0)
    {
        numPixelGrouping = 1.0;
    }
    
    int posX = int(ceil(fmod(floor(fragCoord.x), numPixelGrouping)));
    int posY = int(ceil(fmod(floor(fragCoord.y), numPixelGrouping)));

    
    if ((posX == 0) && (posY == 0))
    {
        currentColor = fragColorAtCoord;
    }
    else
    {
        diffFragCoordXY = float2(fragCoord.x - float(posX), fragCoord.y - float(posY));
        
        uv2 = diffFragCoordXY / iResolution.xy;

        currentColor = inTexture.sample(s, uv2);
    }
    
//    {    O = texture2D(iChannel0,(U-mod(ceil(U), 16.)) / iResolution.xy);  }
    outTexture.write(currentColor, gid);
}


