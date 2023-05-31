//
//  VibesKernel.metal
//  Wonder
//
//  Created by PEXAVC on 8/17/19.
//  Copyright © 2019 PEXAVC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void VibesKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
//                        texture2d<float, access::read> depthTexture [[ texture(1) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        constant float& time [[ buffer(0) ]],
                        constant float& threshold [[ buffer(1) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    
    // This assists in depth output masking
    // That is, excluding the pixels with 0 alpha
    //
    if (inTexture.read(gid).a == 0.0) {
        return;
    }
    
    float widthOrig = inTexture.get_width();
    float heightOrig = inTexture.get_height();
    
    float2 ngid = float2(gid);
    ngid.x /= widthOrig;
    ngid.y /= heightOrig;
    
    float4 orig = inTexture.read(gid);
    
    float2 p = -1.0 + 2.0 * orig.xy;
    
    float iGlobalTime = time;
    
    float x = p.x;
    float y = p.y;
    
    float mov0 = x + y + 1.0 * cos( 2.0*sin(iGlobalTime)) + 11.0 * sin(x/1.);
    float mov1 = y / 0.9 + iGlobalTime;
    float mov2 = x / 0.2;
    
    float c1 = abs( 0.5 * sin(mov1 + iGlobalTime) + 0.5 * mov2 - mov1 - mov2 + iGlobalTime );
    float c2 = abs( sin(c1 + sin(mov0/2. + iGlobalTime) + sin(y/1.0 + iGlobalTime) + 3.0 * sin((x+y)/1.)) );
    float c3 = abs( sin(c2 + cos(mov1 + mov2 + c2) + cos(mov2) + sin(x/1.)) );
    
    float4 colorAtPixel = float4(c1, c2, c3, 1.0);
    
    outTexture.write(mix(orig, colorAtPixel, threshold), gid);
}
