#include <metal_stdlib>
using namespace metal;

struct Uniforms { float4 ink; float4 paper; float4 scene; float4 activity; };
struct Vertex { float4 position [[position]]; float2 uv; };

vertex Vertex aquariumVertex(uint id [[vertex_id]]) {
  float2 p = float2((id << 1) & 2, id & 2);
  return {float4(p * float2(2, -2) + float2(-1, 1), 0, 1), p};
}

float noise(float n) { return fract(sin(n * 12.9898f) * 43758.5453f); }

// Ordered stipple keeps every output pixel in the theme's two-color palette.
bool stipple(float2 p, float coverage) {
  constexpr int bayer[16] = {0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
  int2 cell = int2(p) & 3;
  return coverage > (float(bayer[cell.y * 4 + cell.x]) + 0.5f) / 16;
}

fragment float4 aquariumFragment(Vertex in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
  float2 size = u.scene.xy;
  float2 p = floor(in.uv * size);
  float t = u.scene.z;
  float food = u.scene.w;
  float floorY = size.y - 20;
  bool ink = false;

  // Gravel and soft caustics, both drawn as anchored stipple rather than grey blur.
  if (p.y > floorY + 3 * sin(p.x * .028f)) {
    ink = stipple(p, .32f + .18f * noise(floor(p.x / 5) + floor(p.y / 3) * 93));
  } else {
    float ray = sin(p.x * .035f + sin(p.y * .025f + t * .2f) * 2 + t * .16f);
    ink = ray > .92f && stipple(p, .07f);
  }

  // Plants have different heights and bending phases; CPU activity bends the current.
  for (int i = 0; i < 12; i++) {
    float base = size.x * noise(float(i) + 20);
    float height = 26 + 50 * noise(float(i) + 71);
    float dy = floorY - p.y;
    float bend = sin(dy * .07f - t * .9f + i) * (3 + u.activity.x * 8) * dy / height;
    float dx = p.x - base - bend;
    if (dy > 0 && dy < height) {
      if (abs(dx) < 1.2f) ink = true;
      float leaf = fmod(dy, 14.0f);
      float side = (int(dy / 14) % 2 == 0) ? 1 : -1;
      if (abs(dx - side * leaf * .7f) < 2 && leaf < 10) ink = true;
    }
  }

  for (int i = 0; i < 28; i++) {
    if (i > 7 + int(u.activity.y * 20)) break;
    float seed = float(i);
    float y = floorY - fmod(t * (10 + noise(seed + 2) * 14) + noise(seed + 9) * floorY, floorY);
    float x = size.x * noise(seed + 45) + sin(y * .055f + seed) * (3 + u.activity.x * 8);
    float r = 1.5f + noise(seed + 14) * 2.5f;
    float d = length(p - float2(x, y));
    if (abs(d - r) < .65f) ink = true;
  }

  // Nine residents (ten after a green streak), with three silhouettes and independent paths.
  for (int i = 0; i < 10; i++) {
    if (i == 9 && u.activity.z < .5f) break;
    float seed = float(i);
    float speed = 8 + noise(seed + 62) * 9;
    float phase = t * speed + noise(seed + 3) * size.x * 2;
    float travel = fmod(phase, 2 * (size.x + 70));
    float direction = travel < size.x + 70 ? 1 : -1;
    float x = (direction > 0 ? travel : 2 * (size.x + 70) - travel) - 35;
    float y = 48 + noise(seed + 18) * (floorY - 80) + sin(t * .65f + seed * 3) * 9;
    // Sulking fish mope along the gravel until the next green build.
    y = mix(y, floorY - 9 - noise(seed + 5) * 8, u.activity.w);
    if (food < 12) {
      float attraction = smoothstep(0.0f, 2.0f, food) * (1 - smoothstep(8.0f, 12.0f, food));
      x = mix(x, size.x * .5f + (seed - 4) * 20, attraction * .8f);
      y = mix(y, 44 + seed * 9 + food * 2, attraction * .8f);
    }
    float scale = (.8f + noise(seed + 32) * .5f) * (1 + .35f * u.activity.z);
    float2 q = (p - float2(x, y)) / scale;
    q.x *= direction;
    float ry = i % 3 == 0 ? 14 : (i % 3 == 1 ? 9 : 6);
    float body = length(q / float2(17, ry));
    bool tail = q.x < -12 && q.x > -27 && abs(q.y) < (-q.x - 10) * .62f;
    bool fin = q.x > -8 && q.x < 7 && q.y < -ry + 2 && q.y > -ry - 7 + abs(q.x) * .5f;
    if (body < 1 || tail || fin) {
      ink = body > .85f || tail || fin || stipple(p, .2f + .25f * (q.y / ry + 1));
      if (i % 3 == 0 && body < .85f && int(q.x + 20) % 8 < 3) ink = true;
      if (length(q - float2(10, -3)) < 2.5f) ink = false;
      if (length(q - float2(11, -3)) < 1.2f) ink = true;
    }
  }

  if (food < 12) {
    for (int i = 0; i < 16; i++) {
      float2 pellet = float2(size.x * .5f + (noise(float(i) + 81) - .5f) * 100,
        14 + food * (7 + noise(float(i) + 51) * 4));
      if (all(abs(p - pellet) < 1.5f)) ink = true;
    }
  }
  return ink ? u.ink : u.paper;
}
