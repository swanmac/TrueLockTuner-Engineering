# State-Driven Architecture Example

This example is derived from the chord-library architecture used by True Lock Tuner.

## What It Demonstrates

- ObservableObject and published UI state
- Dependency injection
- Service boundaries
- Combine publishers
- Main-thread state updates
- Debounced search
- Filtering and sorting
- Loading and error states
- Separation of presentation logic from SwiftUI views

## Production Differences

The public example uses simplified protocols and chord models so the architecture can be reviewed independently from the complete application.

The production application includes richer chord models, voicings, search behavior, favorites, recents, and additional application-specific services.
