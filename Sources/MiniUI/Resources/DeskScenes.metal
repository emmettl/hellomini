#include <metal_stdlib>
using namespace metal;
struct DeskUniforms { float4 ink, paper, options; };
struct DeskVertex { float4 position [[position]]; float2 uv; };
vertex DeskVertex deskVertex(uint id [[vertex_id]]) {
  float2 p = float2((id << 1) & 2, id & 2);
  return {float4(p * float2(2,-2) + float2(-1,1),0,1),p};
}
fragment float4 deskFragment(DeskVertex in [[stage_in]], constant DeskUniforms &u [[buffer(0)]]) {
  float2 p = (in.uv - .5f) * float2(u.options.x, 1) * 2.5f;
  float t = u.options.y;
  float shade = 0;
  if (u.options.z < .5f) {
    float zoom = .65f + .55f * cos(t * .12f);
    float2 c = p * zoom + float2(-.65f, .06f);
    float2 z = 0;
    int steps = 0;
    for (int i=0;i<64;i++) {
      z = float2(z.x*z.x-z.y*z.y,2*z.x*z.y)+c;
      if (dot(z,z)>64) break;
      steps++;
    }
    shade = steps == 64 ? 1 : fract(float(steps) * .08f);
  } else if (dot(p,p)<1) {
    float3 n = float3(p.x,-p.y,sqrt(1-dot(p,p)));
    float a = t * .15f;
    float3 r = float3(n.x*cos(a)+n.z*sin(a), n.y, -n.x*sin(a)+n.z*cos(a));
    float lon = atan2(r.x,r.z), lat = asin(r.y);
    // Deliberately stylized continents, not a geographic or daylight reference.
    float land = sin(lon*2+sin(lat*3))*cos(lat*3-lon) + .4f*sin(lon*5+lat*4);
    float grid = min(abs(sin(lon*12)), abs(sin(lat*12)));
    float light = max(.12f,dot(n,normalize(float3(-.6f,.6f,1))));
    shade = land>.2f ? .25f+.65f*(1-light) : .06f+.22f*(1-light);
    if(grid<.035f) shade=.75f;
    if(n.z<.075f)shade=1;
  }
  int2 cell = int2(in.position.xy) & 3;
  constexpr int bayer[16]={0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
  return shade>(float(bayer[cell.y*4+cell.x])+.5f)/16 ? u.ink : u.paper;
}
