//
//  Waveform.metal
//  Spitr
//
//  "Strands" waveform — a faithful Metal port of the reactbits.dev glow/colour
//  maths (soft thick threads, 4-colour palette, intensity tonemap), with the
//  amplitude and intensity driven by the current (smoothed) voice level instead
//  of constant props. At rest the threads collapse into a thin bright spindle;
//  louder voice swells the amplitude so they fan apart and flow — Siri-like.
//  SwiftUI colorEffect; premultiplied, fades at every edge so the panel shows
//  no box.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant float PI = 3.14159265;

// reactbits default palette: red, violet, cyan, amber. The flowing hue sweep
// across these (plus additive overlap → white core) gives the rich glow.
constant float3 kPalette[4] = {
    float3(1.000, 0.259, 0.259),
    float3(0.486, 0.227, 0.929),
    float3(0.024, 0.714, 0.831),
    float3(0.918, 0.702, 0.031)
};

static float3 samplePalette(float t) {
    t = fract(t);
    float scaled = t * 4.0;
    int idx = int(floor(scaled));
    float blend = fract(scaled);
    int next = (idx + 1) & 3;
    return mix(kPalette[idx & 3], kPalette[next], blend);
}

[[ stitchable ]]
half4 strands(float2 position, half4 color, float2 size, float time, float level) {
    const int   strandCount = 3;
    const float uGlow       = 2.6;
    const float uSaturation = 1.4;

    // Remap the incoming level so the swell tracks *how loud* the voice is, not
    // just whether there is any. The level arrives sqrt-compressed (~0.45–0.9 for
    // speech); gate ambient at the bottom, use the real speech span, expand a
    // touch. No saturating boost → soft vs. loud stay distinguishable.
    float v = clamp((level - 0.16) / 0.74, 0.0, 1.0);
    v = pow(v, 1.4);   // expand: soft stays small, loud grows → wider range

    // Aspect-correct centred coords (Y flipped to GL convention).
    float xn = clamp(position.x / size.x, 0.0, 1.0);
    float ux = (position.x - 0.5 * size.x) / size.y;
    float uy = ((size.y - position.y) - 0.5 * size.y) / size.y;

    // Intensity drives brightness/thickness. Separation and wiggle BOTH scale
    // with loudness, so at rest the three threads sit on the centre line (one
    // strand) and only fan apart as the voice gets louder.
    float e = 0.12 + v * 0.88;
    float separation = v * 0.26;   // vertical band offset at full loudness
    float wiggleAmp  = v * 0.08;   // flowing wave grows with the voice too

    // Clean spindle: concentrated in the centre, tapering to a point at the tips.
    float env = pow(sin(xn * PI), 2.0);

    float3 col = float3(0.0);

    for (int i = 0; i < strandCount; i++) {
        float fi = float(i);
        float offset = fi - float(strandCount - 1) * 0.5;   // -1, 0, +1
        float ph = fi * 1.7;
        // Low frequency → each strand is a single smooth arc across the width,
        // not a wavy multi-hump line.
        float freq = 0.7 + fi * 0.15;
        float spd = 1.4 + fi * 1.2;
        float tt = time * 0.65;

        float w = sin(ux * freq + tt * spd + ph) * 0.60
                + sin(ux * freq * 1.1 - tt * spd * 0.7 + ph * 1.7) * 0.40;

        // Band offset (loudness-driven separation) plus a small flowing wiggle,
        // converging to the centre at the tips via env.
        float y = (offset * separation + w * wiggleAmp) * env;

        float d = abs(uy - y);
        float thick = (0.011 + 0.045 * e) * (0.40 + env) * 0.8;   // soft, wide glow
        float g = thick / (d + thick * 0.45);
        g = g * g;

        float h = fi / float(strandCount) + ux * 0.30 + time * 0.04;
        col += samplePalette(h) * g * env;
    }

    col *= 0.45 + 0.7 * e;
    col = 1.0 - exp(-col * uGlow);                 // tonemap → soft bloom
    float gray = dot(col, float3(0.2126, 0.7152, 0.0722));
    col = max(mix(float3(gray), col, uSaturation), 0.0);

    // Fade at top/bottom so the bloom never hits the panel edge.
    float vEdge = smoothstep(0.5, 0.36, abs(uy));

    float lum = max(max(col.r, col.g), col.b);
    float cover = smoothstep(0.03, 0.18, lum);     // kill faint haze → true transparency
    float a = clamp(lum, 0.0, 1.0) * cover * vEdge;

    return half4(half3(col * cover * vEdge), half(a));
}
