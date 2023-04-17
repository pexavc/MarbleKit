#include <metal_stdlib>
using namespace metal;

kernel void PODownsample(texture2d<float, access::sample> inTexture [[texture(0)]],
                             texture2d<float, access::write> outTexture [[texture(1)]],
                             uint2 gid [[thread_position_in_grid]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);

    float w = outTexture.get_width();

    float4 color = inTexture.sample(s, float2(gid) * float2(1.0/w, 1.0/outTexture.get_height()));
    outTexture.write(color, gid);
}
