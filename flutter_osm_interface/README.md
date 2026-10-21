# flutter_osm_interface

Shared platform contracts, types, events, and serialization for
`flutter_osm_plugin` and its federated platform packages.

- `OSMPlatform` / `MobileOSMPlatform`: platform-facing map contracts.
- `MethodChannelOSM`: default transport, including shared iOS/macOS payloads.
- Typed Android transport commands/events for the Android host and optional JNI
  transport.
- Geographic types and platform-aware tile, color, and marker serialization,
  including Web-safe encoding on Apple browser hosts.

Version 1.7.0 adds macOS serialization and map-channel cleanup while preserving
existing public contracts. `flutter_osm_plugin` 3.0.0 requires `^1.7.0`.
Applications normally depend on the main plugin rather than this package directly.
Native Apple SPM integration belongs to the main plugin's `darwin/` package.
