# StoreKit 2 Purchase Example

This example is derived from the purchase and entitlement architecture used by True Lock Tuner's one-time Pro upgrade.

## What It Demonstrates

- StoreKit 2 product loading
- async/await purchase workflows
- Transaction verification
- Transaction.updates monitoring
- Current entitlement inspection
- Purchase restoration with AppStore.sync()
- Verified transaction completion
- Pending and cancelled purchase states
- MainActor-managed UI state
- Separation between StoreKit and application-specific feature access

## Production Differences

The production implementation includes additional application-specific behavior that has intentionally been removed from this public example, including:

- The real App Store product identifier
- Application entitlement management
- Analytics events
- OSLog diagnostics
- StoreKit testing guidance
- Customer-facing localization
- Product-specific error handling

The sample focuses on the StoreKit 2 lifecycle rather than exposing the complete commercial implementation.
