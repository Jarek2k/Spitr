//
//  Waveform.metal
//  Spitr
//
//  "Strands" waveform — Siri-like. At rest the three coloured threads collapse
//  into one thin bright spindle. As the voice gets louder a single global
//  amplitude swells: the threads fan apart vertically and flow, converging again
//  at the left/right tips. Driven by the current (smoothed) audio level, not a
//  scrolling history — so it reads as a living glow that reacts to loudness,
//  not as a shaped bar graph. SwiftUI colorEffect; premultiplied output that
//  fades at all edges so the floating panel shows no box.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant float PI = 3.14159265;

// Default reactbits palette: cyan/blue (top), white core, violet/pink (bottom)
// emerge from these three additively.
constant float3 kPalette[3] = {
    float3(0.140, 0.760, 0.980),   // cyan-blue
    float3(1.000, 0.980, 0.940),   // warm white
    float3(0.890, 0.300, 0.760)    // violet-pink
};

[[ stitchable ]]
half4 strands(float2 position, half4 color, float2 size, float time, float level) {
    const int   strandCount = 3;
    const float uGlow       = 2.6;
    const float uSaturation = 1.35;

    // Current loudness (already smoothed on the CPU); RMS is small → boost.
    float lvl = clamp(level * 1.8, 0.0, 1.0);

    float xn = clamp(position.x / size.x, 0.0, 1.0);
    float uy = ((size.y - position.y) - 0.5 * size.y) / size.y;   // -0.5 … 0.5

    // Spindle envelope: 0 at the left/right tips, 1 in the centre.
    float env = pow(sin(xn * PI), 1.3);

    // Global swell: tiny at rest (threads merged → thin line), large when loud
    // (threads fan apart). This is the whole behaviour the user is after.
    float amp = (0.012 + lvl * 0.46) * env;

    float3 col = float3(0.0);

    for (int i = 0; i < strandCount; i++) {
        float fi = float(i);
        float offset = fi - float(strandCount - 1) * 0.5;   // -1, 0, +1

        // Gentle flowing curve (low frequency → smooth humps like the reference).
        float w = sin(xn * 6.2831 * 0.9 + time * 0.9 + fi * 2.1) * 0.6
                + sin(xn * 6.2831 * 1.6 - time * 0.6 + fi * 1.1) * 0.4;

        // Static fan-out (banding) plus the flowing wiggle, both scaled by swell.
        float y = (offset * 0.62 + w * 0.42) * amp;

        float d = abs(uy - y);
        float thick = 0.006 + 0.012 * lvl;       // thin core, a touch fatter when loud
        float g = thick / (d + thick * 0.5);
        g = g * g;

        col += kPalette[i] * g;
    }

    col = 1.0 - exp(-col * uGlow);               // tonemap → soft glow
    float gray = dot(col, float3(0.2126, 0.7152, 0.0722));
    col = max(mix(float3(gray), col, uSaturation), 0.0);

    // Fade at top/bottom so the glow never hits the panel edge.
    float vEdge = smoothstep(0.5, 0.30, abs(uy));

    float lum = max(max(col.r, col.g), col.b);
    float cover = smoothstep(0.04, 0.20, lum);   // kill faint haze → true transparency
    float a = clamp(lum, 0.0, 1.0) * cover * vEdge;

    return half4(half3(col * cover * vEdge), half(a));
}
