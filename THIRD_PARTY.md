# Third-Party Notices

Spitr bundles or derives from the following third-party work. Each is used
under its own license; the originals' copyright and license terms apply.

## Swift packages

| Package | Author | License | Use |
|---|---|---|---|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | Argmax, Inc. | MIT | Optional on-device transcription engine (Whisper on the Apple Neural Engine). |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | Apple Inc. | Apache-2.0 | Transitive dependency of WhisperKit. |

WhisperKit downloads its model files once, on first activation, from the
Hugging Face Hub. After that it runs fully offline. No other network calls are
made by Spitr (see the privacy section of the README).

## Shader

`Spitr/Features/Overlay/Waveform.metal` ("Strands" waveform style) is a Metal
port of the glow/colour mathematics from a [React Bits](https://www.reactbits.dev)
component. React Bits is published under the MIT License. The Metal code here is
an original re-implementation; the palette and intensity-tonemap approach are
adapted from the original.

## Full license texts

- MIT (WhisperKit, React Bits): see the [`LICENSE`](LICENSE) file in this repo —
  the same MIT terms apply, with copyright held by the respective authors above.
- Apache-2.0 (swift-argument-parser): https://www.apache.org/licenses/LICENSE-2.0

If you believe an attribution is missing or incorrect, please open an issue.
