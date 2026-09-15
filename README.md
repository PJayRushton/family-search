# Family Search

An offline-first iPhone person browser built for the supplied take-home exercise.

## Requirements

- Xcode 26 or newer
- An iOS 17.0 or newer simulator

## Run

1. Open `FamilySearch.xcodeproj`.
2. Select the `FamilySearch` scheme and an iPhone simulator.
3. Press Run.

No package installation, code generation, API key, or build-setting edit is required.

## Current status

The project foundation and MVVM boundaries are established. Feature behavior will be added through the child issues linked from [epic #1](https://github.com/PJayRushton/family-search/issues/1).

See [ARCHITECTURE.md](ARCHITECTURE.md) for dependency boundaries and concurrency ownership.

## Scaling the persistence design

The assignment's small list response is stored in one transaction, while full profiles and portraits are cached only when requested. At 100,000 people, the server contract would need pagination or incremental sync; the client would ingest pages in bounded batches and store per-record sync metadata such as revisions and tombstones. Stable person IDs would remain indexed for direct lookups, and list queries would use indexed sort/search fields rather than loading all records. Portrait storage would add size accounting, last-access metadata, and an eviction policy so binary data cannot grow without bound.
