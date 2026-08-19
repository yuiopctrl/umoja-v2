# 0001 — Single Flutter Codebase

## Status

Accepted

## Context

Umoja v2 needs to run on Android, iOS, Web, Linux, Windows, and macOS.
The old Umoja codebase is not being reused. We need to decide whether the
client is one shared codebase or multiple platform-specific stacks (e.g.
a separate React web frontend, a separate React Native mobile app, and/or
a separate desktop frontend).

## Decision

Use a single Flutter codebase (`app/`) targeting all six platforms.
Platform-specific implementation is used only where technically
necessary (e.g. a plugin with a platform-specific implementation), never
as a separate parallel frontend stack.

## Consequences

- Domain logic and UI are shared across all platforms, reducing
  duplication and drift between them.
- The UI must be built responsively from the start — it cannot assume a
  single fixed viewport or input model (touch vs. mouse/keyboard).
- Some integrations may still need platform-specific adapters
  (implemented within the Flutter project, e.g. via plugins or
  conditional imports), not a separate codebase.
- iOS and macOS production builds require Apple tooling and a macOS host.
- Windows desktop production builds require a Windows host with the
  appropriate toolchain.
- Web builds may require browser-specific considerations (e.g. storage,
  URL strategy, CORS with Supabase).
- We explicitly do not create a separate React web frontend, React Native
  app, or separate desktop frontend for this product.
