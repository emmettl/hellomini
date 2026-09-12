#include <metal_stdlib>
using namespace metal;

struct Vertex { float4 position; float4 normal; };
struct Uniforms {
    float4x4 transform;
    float4x4 rotation;
    float4 ink;
    float4 paper;
    float4 options; // mode, dither cell size in drawable pixels, unused, unused
};
struct Raster {
    float4 position [[position]];
    float3 normal;
    float3 viewPosition;
};
vertex Raster teapotVertex(uint id [[vertex_id]], const device Vertex *vertices [[buffer(0)]],
                          constant Uniforms &u [[buffer(1)]]) {
    Raster out;
    out.position = u.transform * vertices[id].position;
    out.normal = (u.rotation * vertices[id].normal).xyz;
    out.viewPosition = (u.rotation * vertices[id].position).xyz;
    return out;
}
fragment float4 teapotFragment(Raster in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    if (u.options.x > 1.5) return u.ink;
    float3 n = normalize(in.normal);
    float3 light = normalize(float3(-0.6, 0.9, 1.4));
    float diffuse = max(0.0, dot(n, light));
    float specular = pow(max(0.0, dot(n, normalize(light + float3(0,0,1)))), 42.0);
    float shade = clamp(0.14 + diffuse * 0.67 + specular * 0.6, 0.06, 0.98);
    if (u.options.x < 0.5) {
        constexpr int bayer[16] = {0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
        uint2 cell = uint2(in.position.xy / max(1.0, u.options.y)) % 4;
        float threshold = (float(bayer[cell.y * 4 + cell.x]) + 0.5) / 16.0;
        shade = shade > threshold ? 1.0 : 0.0;
    }
    return mix(u.ink, u.paper, shade);
}
