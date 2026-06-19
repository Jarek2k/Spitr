//
//  Waveform.metal
//  Spitr
//
//  "Strands" waveform — a Metal port of the reactbits.dev WebGL effect
//  (https://reactbits.dev/animations/strands). Glowing, multi-coloured threads
//  with an additive bloom. Amplitude, intensity and speed are driven by the
//  live audio level so the motion follows the voice. Used as a SwiftUI
//  colorEffect; output is premultiplied so the glow composites over the dark
//  overlay.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant float PI = 3.14159265;

// Default reactbits palette: red, violet, cyan, amber.
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
    // Fixed look (reactbits defaults).
    const int   strandCount = 3;
    const float uWaviness   = 1.0;
    const float uThickness  = 0.7;
    const float uGlow       = 2.6;
    const float uTaper      = 3.0;
    const float uSpread     = 1.0;
    const float uHueShift   = 0.0;
    const float uSaturation = 1.5;
    const float uScale      = 1.5;
    const float uOpacity    = 1.0;

    // Audio-reactive: at rest the threads are calm and dim; the voice drives
    // amplitude, brightness and speed. `level` is boosted because RMS is small.
    float lvl = clamp(level * 1.6, 0.0, 1.0);
    float uIntensity = clamp(0.05 + lvl * 1.1, 0.0, 1.0);
    float uAmplitude = 0.08 + lvl * 2.6;
    float uSpeed     = 0.5 + lvl * 1.6;

    // Aspect-correct, centred UV (flip Y: SwiftUI is top-down, GL bottom-up).
    float2 frag = float2(position.x, size.y - position.y);
    float2 uv = (frag - 0.5 * size) / size.y;
    uv /= max(uScale, 0.0001);

    float e = 0.06 + uIntensity * 0.94;
    float env = pow(max(cos(uv.x * PI * 1.3), 0.0), uTaper);

    float3 col = float3(0.0);
    for (int i = 0; i < strandCount; i++) {
        float fi = float(i);
        float ph = fi * 1.7 * uSpread;
        float freq = (2.0 + fi * 0.35) * uWaviness;
        float spd = 1.4 + fi * 1.2;
        float tt = time * uSpeed;

        float w = sin(uv.x * freq + tt * spd + ph) * 0.60
                + sin(uv.x * freq * 1.1 - tt * spd * 0.7 + ph * 1.7) * 0.40;

        float amp = (0.1 + 0.02 * e) * env * uAmplitude;
        float y = w * amp;

        float d = abs(uv.y - y);
        float thick = (0.001 + 0.05 * e) * (0.35 + env) * uThickness;
        float g = thick / (d + thick * 0.45);
        g = g * g;

        float h = fi / float(strandCount) + uv.x * 0.30 + time * 0.04 + uHueShift;
        col += samplePalette(h) * g * env;
    }

    col *= 0.45 + 0.7 * e;
    col = 1.0 - exp(-col * uGlow);              // tonemap → soft glow

    float gray = dot(col, float3(0.2126, 0.7152, 0.0722));
    col = max(mix(float3(gray), col, uSaturation), 0.0);

    float lum = max(max(col.r, col.g), col.b);
    // Cut the faint glow tail so the panel stays truly transparent (no visible
    // rectangle edge); the floating overlay has no dark background to hide it.
    float cover = smoothstep(0.04, 0.20, lum);
    float alpha = clamp(lum, 0.0, 1.0) * cover * uOpacity;

    // Premultiplied output (matches reactbits ONE / ONE_MINUS_SRC_ALPHA blend).
    return half4(half3(col * cover * uOpacity), half(alpha));
}
