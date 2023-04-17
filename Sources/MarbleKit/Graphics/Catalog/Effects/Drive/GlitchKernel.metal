////
////  GlitchKernel.metal
////  Wonder
////
////  Created by 0xKala on 8/14/19.
////  Copyright © 2019 0xKala. All rights reserved.
////
//
//#include <metal_stdlib>
//using namespace metal;
//
//float random(float2 c){
//    return fract(sin(dot(c.xy, float2(12.9898,78.233))) * 43758.5453);
//}
//
//float mod(float x, float y) {
//    return x - floor(x * (1.0 / y));
//}
//
//float3 mod289x3(float3 x) {
//    return x - floor(x * (1.0 / 289.0)) * 289.0;
//}
//
//float4 mod289(float4 x) {
//    return x - floor(x * (1.0 / 289.0)) * 289.0;
//}
//
//float4 permute(float4 x) {
//    return mod289(((x*34.0)+1.0)*x);
//}
//
//float4 taylorInvSqrt(float4 r)
//{
//    return 1.79284291400159 - 0.85373472095314 * r;
//}
//
//float snoise3(float3 v)
//{
//    const float2 C = float2(1.0/6.0, 1.0/3.0) ;
//    const float4 D = float4(0.0, 0.5, 1.0, 2.0);
//    
//    // First corner
//    float3 i  = floor(v + dot(v, C.yyy) );
//    float3 x0 =   v - i + dot(i, C.xxx) ;
//    
//    // Other corners
//    float3 g = step(x0.yzx, x0.xyz);
//    float3 l = 1.0 - g;
//    float3 i1 = min( g.xyz, l.zxy );
//    float3 i2 = max( g.xyz, l.zxy );
//    
//    //   x0 = x0 - 0.0 + 0.0 * C.xxx;
//    //   x1 = x0 - i1  + 1.0 * C.xxx;
//    //   x2 = x0 - i2  + 2.0 * C.xxx;
//    //   x3 = x0 - 1.0 + 3.0 * C.xxx;
//    float3 x1 = x0 - i1 + C.xxx;
//    float3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
//    float3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y
//    
//    // Permutations
//    i = mod289x3(i);
//    float4 p = permute( permute( permute(
//                                         i.z + float4(0.0, i1.z, i2.z, 1.0 ))
//                                + i.y + float4(0.0, i1.y, i2.y, 1.0 ))
//                       + i.x + float4(0.0, i1.x, i2.x, 1.0 ));
//    
//    // Gradients: 7x7 points over a square, mapped onto an octahedron.
//    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
//    float n_ = 0.142857142857; // 1.0/7.0
//    float3  ns = n_ * D.wyz - D.xzx;
//    
//    float4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)
//    
//    float4 x_ = floor(j * ns.z);
//    float4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)
//    
//    float4 x = x_ *ns.x + ns.yyyy;
//    float4 y = y_ *ns.x + ns.yyyy;
//    float4 h = 1.0 - abs(x) - abs(y);
//    
//    float4 b0 = float4( x.xy, y.xy );
//    float4 b1 = float4( x.zw, y.zw );
//    
//    //float4 s0 = float4(lessThan(b0,0.0))*2.0 - 1.0;
//    //float4 s1 = float4(lessThan(b1,0.0))*2.0 - 1.0;
//    float4 s0 = floor(b0)*2.0 + 1.0;
//    float4 s1 = floor(b1)*2.0 + 1.0;
//    float4 sh = -step(h, float4(0.0));
//    
//    float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
//    float4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;
//    
//    float3 p0 = float3(a0.xy,h.x);
//    float3 p1 = float3(a0.zw,h.y);
//    float3 p2 = float3(a1.xy,h.z);
//    float3 p3 = float3(a1.zw,h.w);
//    
//    //Normalise gradients
//    float4 norm = taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
//    p0 *= norm.x;
//    p1 *= norm.y;
//    p2 *= norm.z;
//    p3 *= norm.w;
//    
//    // Mix final noise value
//    float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
//    m = m * m;
//    return 42.0 * dot( m*m, float4( dot(p0,x0), dot(p1,x1),
//                                   dot(p2,x2), dot(p3,x3) ) );
//}
//
//
//kernel void GlitchKernel(texture2d<float, access::sample> inTexture [[texture(0)]],
//                         texture2d<float, access::write> outTexture [[texture(1)]],
//                         constant float& time [[buffer(0)]],
//                         constant float& threshold [[buffer(1)]],
//                         constant float& isIPhone6 [[buffer(2)]],
//                         uint2 gid [[thread_position_in_grid]]){
//    
//    // This assists in depth output masking
//    // That is, excluding the pixels with 0 alpha
//    //
//    if (inTexture.read(gid).a == 0.0) {
//        return;
//    }
//    
//    float2 resolution = float2(outTexture.get_width(), outTexture.get_height());
//    float interval = 3.0;
//    float w = float(inTexture.get_width());
//    float h = float(inTexture.get_height());
//    float2 vUv = float2(gid) * float2(1.0/w, 1.0/h);
//    constexpr sampler s(address::repeat, filter::linear, coord::normalized);
//    
//    
//    float strength = smoothstep(interval * 0.5, interval, interval - mod(time, interval));
//    float2 shake = float2(strength * 8.0 + 0.5) * float2(
//                                                         random(float2(time)) * 2.0 - 1.0,
//                                                         random(float2(time * 2.0)) * 2.0 - 1.0
//                                                         ) / resolution;
//    
//    float y = vUv.y * resolution.y;
//    float rgbWave = (snoise3(float3(0.0, y * 0.01, time * 400.0)) * (2.0 + strength * 32.0)
//                     * snoise3(float3(0.0, y * 0.02, time * 200.0)) * (1.0 + strength * 4.0)
//                     + step(0.9995, sin(y * 0.005 + time * 1.6)) * 12.0
//                     + step(0.9999, sin(y * 0.005 + time * 2.0)) * -18.0
//                     ) / resolution.x;
//    float rgbDiff = (6.0 + sin(time * 500.0 + vUv.y * 40.0) * (20.0 * strength + 1.0)) / resolution.x;
//    float rgbUvX = vUv.x + rgbWave;
//    float r = inTexture.sample(s, float2(rgbUvX + rgbDiff, vUv.y) + shake).r;
//    float g = inTexture.sample(s, float2(rgbUvX, vUv.y) + shake).g;
//    float b = inTexture.sample(s, float2(rgbUvX - rgbDiff, vUv.y) + shake).b;
//    
//    float whiteNoise = (random(vUv + mod(time, 10.0)) * 2.0 - 1.0) * (0.15 + strength * 0.15);
//    
//    float bnTime = floor(time * 20.0) * 200.0;
//    float noiseX = step((snoise3(float3(0.0, vUv.x * 3.0, bnTime)) + 1.0) / 2.0, 0.12 + strength * 0.3);
//    float noiseY = step((snoise3(float3(0.0, vUv.y * 3.0, bnTime)) + 1.0) / 2.0, 0.12 + strength * 0.3);
//    float bnMask = noiseX * noiseY;
//    float bnUvX = vUv.x + sin(bnTime) * 0.2 + rgbWave;
//    float bnR = inTexture.sample(s, float2(bnUvX + rgbDiff, vUv.y)).r * bnMask;
//    float bnG = inTexture.sample(s, float2(bnUvX, vUv.y)).g * bnMask;
//    float bnB = inTexture.sample(s, float2(bnUvX - rgbDiff, vUv.y)).b * bnMask;
//    float4 blockNoise = float4(bnR, bnG, bnB, 1.0);
//    
//    float bnTime2 = floor(time * 25.0) * 300.0;
//    float noiseX2 = step((snoise3(float3(0.0, vUv.x * 2.0, bnTime2)) + 1.0) / 2.0, 0.12 + strength * 0.5);
//    float noiseY2 = step((snoise3(float3(0.0, vUv.y * 8.0, bnTime2)) + 1.0) / 2.0, 0.12 + strength * 0.3);
//    float bnMask2 = noiseX2 * noiseY2;
//    float bnR2 = inTexture.sample(s, float2(bnUvX + rgbDiff, vUv.y)).r * bnMask2;
//    float bnG2 = inTexture.sample(s, float2(bnUvX, vUv.y)).g * bnMask2;
//    float bnB2 = inTexture.sample(s, float2(bnUvX - rgbDiff, vUv.y)).b * bnMask2;
//    float4 blockNoise2 = float4(bnR2, bnG2, bnB2, 1.0);
//    
//    float waveNoise = (sin(vUv.y * 1200.0) + 1.0) / 2.0 * (0.15 + strength * 0.2);
//    
//
//    outTexture.write(float4(r, g, b, 1.0) * (1.0 - bnMask - bnMask2) + (whiteNoise + blockNoise + blockNoise2 - waveNoise), gid);
//}
