// SPDX-License-Identifier: GPL-3.0-or-later
#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uCurlX;
uniform float uRadius;
uniform float uShadows;
uniform float uOverlay;
uniform float uFlip;
uniform vec3 uPaper;
uniform sampler2D uFront;
uniform sampler2D uUnder;

out vec4 fragColor;

const float PI = 3.14159265359;

vec4 sampleFront(float x, float y) {
  float sx = uFlip > 0.5 ? uSize.x - x : x;
  return texture(uFront, vec2(sx, y) / uSize);
}

vec4 sampleUnder(vec2 p, float shade) {
  if (uOverlay > 0.5) return vec4(0.0, 0.0, 0.0, shade);
  vec2 sp = vec2(uFlip > 0.5 ? uSize.x - p.x : p.x, p.y);
  vec4 c = texture(uUnder, sp / uSize);
  c.rgb *= 1.0 - shade;
  return c;
}

vec4 paperBack(vec4 c, float shade) {
  vec3 rgb = mix(c.rgb, uPaper, 0.55);
  return vec4(rgb * shade, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float W = uSize.x;
  float c = uCurlX;
  float r = max(uRadius, 1.0);
  float x = uFlip > 0.5 ? W - p.x : p.x;

  float xEdge = 2.0 * c - W + PI * r;
  bool hasBack = xEdge < c;
  float xr = c + r * sin(min(max(W - c, 0.0) / r, 0.5 * PI));
  float lift = clamp(xr / r, 0.0, 1.0);

  vec4 col;

  if (x < c) {
    if (hasBack && x >= xEdge) {
      float u = 2.0 * c - x + PI * r;
      col = paperBack(sampleFront(u, p.y), 0.93);
    } else {
      col = sampleFront(x, p.y);
      if (hasBack) {
        float t = clamp((xEdge - x) / (r * 1.2), 0.0, 1.0);
        col.rgb *= 1.0 - uShadows * 0.30 * (1.0 - t) * (1.0 - t);
      }
    }
  } else if (x <= xr) {
    float s = clamp((x - c) / r, 0.0, 1.0);
    float th1 = asin(s);
    float th2 = PI - th1;
    float u2 = c + r * th2;
    if (u2 <= W) {
      col = paperBack(sampleFront(u2, p.y), mix(0.95, 0.62, s * s));
    } else {
      float u1 = c + r * th1;
      col = sampleFront(u1, p.y);
      col.rgb *= 1.0 - uShadows * 0.30 * s;
    }
  } else {
    float t = clamp((x - xr) / (r * 1.6), 0.0, 1.0);
    col = sampleUnder(p, uShadows * lift * 0.35 * (1.0 - t) * (1.0 - t));
  }

  fragColor = col;
}
