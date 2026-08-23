# Audio Processing Example

This sample demonstrates the structure of the microphone and monophonic tuning pipeline used by True Lock Tuner.

## What It Demonstrates

- AVAudioSession configuration
- Microphone permission handling
- AVAudioEngine input capture
- PCM buffer processing
- RMS-based noise gating
- Rolling median filtering
- Note-change stabilization
- Idle-state handling
- Main-thread publication for SwiftUI
- Separation between audio capture and pitch-analysis logic

## Production Differences

The shipping application contains additional behavior that is intentionally excluded from this public example, including:

- Proprietary pitch-detection implementation
- Live chord-recognition algorithms
- Chroma analysis and chord-template matching
- Production tuning thresholds
- Guitar-string selection logic
- Application-specific state and analytics

The purpose of this sample is to demonstrate the engineering structure of the real-time audio pipeline without publishing the complete commercial implementation.
