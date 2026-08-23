# True Lock Tuner Architecture Overview

True Lock Tuner is structured as a collection of native iOS features coordinated through shared application state and reusable SwiftUI components.

The goal of the architecture is to keep individual tools modular enough to evolve independently while preserving a consistent user experience across the application.

## Core Areas

### Audio Processing

Microphone-driven features use AVFoundation to capture and process incoming audio.

The audio pipeline supports:

- Pitch detection
- Tuning feedback
- Live chord recognition
- Noise handling
- Stable interface updates

Audio processing is separated from presentation logic so incoming measurements can be processed before being displayed by SwiftUI views.

---

### Application State

The interface is driven by application state rather than direct coupling between views and low-level services.

State includes areas such as:

- Current tuning configuration
- Detected pitch and note information
- Metronome state
- Practice-tool configuration
- Premium entitlement state
- User preferences

SwiftUI views react to changes in this state and remain focused primarily on presentation and interaction.

---

### Feature Separation

Major application features are designed as distinct areas of responsibility:

- Tuner
- Detect Chord
- Metronome
- Tempo Trainer
- Gap Click
- Chord Library
- Alternate Tunings
- Practice Tracking
- Premium Features

This structure allows features to be updated or expanded without requiring unrelated parts of the application to be rewritten.

---

### Premium Feature Management

Free and Pro functionality is controlled through shared entitlement state.

The purchase workflow includes:

- StoreKit 2
- One-time Pro purchase
- Entitlement validation
- Purchase restoration
- Premium feature gating

Views respond to entitlement state rather than managing purchase logic directly.

---

### Analytics

TelemetryDeck is used for privacy-focused analytics.

Analytics events help evaluate:

- Feature adoption
- Core workflow usage
- Premium feature interaction
- Product improvements after release

Analytics code is kept separate from core feature behavior whenever possible.

---

### Testing Strategy

Testing includes both simulator and physical-device validation.

Physical-device testing is especially important for:

- Microphone behavior
- Pitch detection
- Chord recognition
- Audio timing
- Haptic feedback
- StoreKit workflows

Production releases also include App Store validation and post-release monitoring.

---

## Architectural Goals

The architecture is designed around several practical goals:

1. Keep audio processing separate from presentation.
2. Maintain clear application state.
3. Build reusable SwiftUI components.
4. Avoid tightly coupling unrelated features.
5. Make premium feature state predictable.
6. Support continued post-launch development without large rewrites.
