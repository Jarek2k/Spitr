//
//  Waveform.metal
//  Spitr
//
//  "Strands" waveform — Metal port of the reactbits.dev effect, adapted so the
//  motion tracks the voice the way the bar waveform does: it reads the same
//  recent-level history buffer and modulates each thread's amplitude/brightness
//  *per x position*, so loud moments bulge and travel left as new samples come
//  in. Quiet input → calm, dim, near-flat threads (with a noise gate so idle
//  mic hiss doesn't make it twitch). Used as a SwiftUI colorEffect; output is
//  premultiplied and fades at all four edges so the floating panel shows no box.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant float PI = 3.14159265;
constant int kCount = 48;   // must match MetalWaveformView.count

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

// SwiftUI's `.floatArray` passes the pointer *and* an int length, so the count
// parameter is required even though we also know it as kCount.
[[ stitchable ]]
half4 strands(float2 position, half4 color, float2 size, float time,
              device const float *levels, int count) {
    const int   strandCount = 3;
    const float uThickness  = 0.7;
    const float uGlow       = 2.4;
    const float uSaturation = 1.4;

    float xn = clamp(position.x / size.x, 0.0, 1.0);   // 0 left … 1 right (newest)

    // Local voice loudness from the history buffer, interpolated and gated so
    // idle noise reads as zero.
    float fidx = xn * float(count - 1);
    int i0 = int(floor(fidx));
    int i1 = min(i0 + 1, count - 1);
    float fr = fidx - float(i0);
    float lvl = mix(levels[i0], levels[i1], fr);
    lvl = clamp((lvl - 0.04) / 0.96, 0.0, 1.0);        // noise gate
    lvl = clamp(lvl * 1.7, 0.0, 1.0);                  // RMS is small → boost

    // Centred vertical coord (-0.5 … 0.5), Y flipped to GL convention.
    float uy = ((size.y - position.y) - 0.5 * size.y) / size.y;

    float env = pow(sin(xn * PI), 1.1);                // horizontal arch → 0 at L/R

    float e = 0.08 + lvl * 0.92;
    float3 col = float3(0.0);

    for (int i = 0; i < strandCount; i++) {
        float fi = float(i);
        float ph = fi * 1.7;
        float freq = 2.2 + fi * 0.6;
        float spd = 1.0 + fi * 0.5;

        float w = sin(xn * freq * 6.2831 + time * spd + ph) * 0.6
                + sin(xn * freq * 6.9   - time * spd * 0.7 + ph * 1.7) * 0.4;

        float amp = (0.03 + lvl * 0.28) * env;          // local amplitude
        float y = w * amp;

        float d = abs(uy - y);
        float thick = (0.004 + 0.02 * e) * uThickness;
        float g = thick / (d + thick * 0.5);
        g = g * g;

        float h = fi / float(strandCount) + xn * 0.30 + time * 0.04;
        col += samplePalette(h) * g * env * (0.22 + 0.9 * lvl);
    }

    col = 1.0 - exp(-col * uGlow);                      // tonemap → soft glow
    float gray = dot(col, float3(0.2126, 0.7152, 0.0722));
    col = max(mix(float3(gray), col, uSaturation), 0.0);

    // Fade to fully transparent at top/bottom so the glow never hits the edge.
    float vEdge = smoothstep(0.5, 0.30, abs(uy));

    float lum = max(max(col.r, col.g), col.b);
    float cover = smoothstep(0.05, 0.22, lum);          // kill faint haze tail
    float a = clamp(lum, 0.0, 1.0) * cover * vEdge;

    return half4(half3(col * cover * vEdge), half(a));
}
