//
//  Waveform.metal
//  Spitr
//
//  "Strands" waveform: a handful of sine threads flowing across the overlay,
//  their amplitude driven by the live audio level. Used as a SwiftUI
//  colorEffect, so it returns a colour per pixel and leaves the rest transparent.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
half4 strands(float2 position, half4 color, float2 size, float time, float level) {
    float2 uv = position / size;

    // Taper amplitude toward the edges so threads meet in a spindle shape.
    float envelope = sin(uv.x * M_PI_F);

    const int strandCount = 3;
    float intensity = 0.0;

    for (int i = 0; i < strandCount; i++) {
        float fi = float(i);
        float phase = time * (1.3 + fi * 0.4) + fi * 1.7;
        float freq = 2.0 + fi * 0.8;
        float amp = (0.06 + 0.34 * level) * (1.0 - fi * 0.2) * envelope;

        float y = 0.5 + sin(uv.x * 6.2831853 * freq + phase) * amp;
        float dist = abs(uv.y - y);

        // Soft line: bright core, quick falloff.
        intensity += smoothstep(0.02, 0.0, dist) * (1.0 - fi * 0.22);
    }

    float alpha = clamp(intensity, 0.0, 1.0);
    half3 tint = half3(1.0);
    // Composite white threads over whatever (near-transparent) pixel was there.
    return half4(tint, 1.0h) * half(alpha) + color * half(1.0 - alpha);
}
