#include <metal_stdlib>
using namespace metal;
struct DeskUniforms { float4 ink, paper, options; };
struct DeskVertex { float4 position [[position]]; float2 uv; };
vertex DeskVertex deskVertex(uint id [[vertex_id]]) {
  float2 p = float2((id << 1) & 2, id & 2);
  return {float4(p * float2(2,-2) + float2(-1,1),0,1),p};
}
// Original procedural pixel artwork: no borrowed screensaver sprites.
float segmentDistance(float2 p, float2 a, float2 b) {
  float2 d = b-a;
  return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.f,1.f));
}
float toasterShade(float2 uv, float aspect, float time) {
  float2 world = floor(uv * float2(300*aspect,300));
  // The whole procession travels diagonally; staggered lanes keep the parade loosely spaced.
  world += float2(time*12, time*5);
  float row = floor(world.y/70);
  world.x += row*43;
  float column = floor(world.x/116);
  float seed = fract(sin(row*17.13f+column*93.71f)*43758.5453f);
  float2 p = float2(fract(world.x/116)*116-58, fract(world.y/70)*70-35);
  p.y += sin(seed*41)*5;
  float shade = 1; // Theme ink behind bright, outlined silhouettes.
  if (seed < .25f) {
    // A slice of toast with a domed crown, crust, and scattered crumbs.
    p = float2(p.x*.94f-p.y*.34f,p.x*.34f+p.y*.94f);
    bool bread = (abs(p.x)<10 && p.y>-6 && p.y<12)
      || length((p-float2(0,-6))/float2(12,7))<1;
    bool inside = (abs(p.x)<8 && p.y>-6 && p.y<10)
      || length((p-float2(0,-6))/float2(10,5))<1;
    if(bread) shade=0;
    if(inside) shade=.32f;
    if(inside && (length(p-float2(-3,-2))<1.2f || length(p-float2(4,5))<1.2f)) shade=1;
    return shade;
  }
  float flap = sin(time*4+seed*18);
  // Feathered wings grow outwards and flap around their shoulder.
  float2 w = float2(abs(p.x)-14,p.y+3);
  float slope = -.45f-.35f*flap;
  float middle = w.x*slope;
  float width = max(0.f,7*(1-w.x/24));
  if(w.x>=0 && w.x<24 && abs(w.y-middle)<width) {
    shade=0;
    if(w.x>5 && fract((w.y-middle+w.x*.2f)/4)<.25f)shade=1;
  }
  // Feet and lever, then a bevelled metal body with a raised top and two slots.
  if(abs(abs(p.x)-11)<3 && p.y>10 && p.y<15)shade=0;
  if(p.x>17 && p.x<22 && p.y>-3 && p.y<1)shade=0;
  float2 b=abs(p-float2(0,1))-float2(15,9);
  float body=length(max(b,0.f))+min(max(b.x,b.y),0.f)-3;
  if(body<0)shade=0;
  if(body < -2)shade=.2f;
  if(p.y>-10 && p.y<-5 && abs(p.x)<14)shade=0;
  if(p.y>-9 && p.y<-7 && abs(p.x)<10)shade=1;
  if(p.y>-5 && p.y<-4 && abs(p.x)<15)shade=1;
  if(segmentDistance(p,float2(-12,0),float2(-12,7))<.7f)shade=0;
  if(length(p-float2(11,5))<2)shade=1;
  return shade;
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
  } else if (u.options.z > 1.5f) {
    shade = toasterShade(in.uv, u.options.x, t);
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
