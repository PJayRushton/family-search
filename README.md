# Family Search

An offline-first SwiftUI person browser built for the supplied take-home exercise. It loads a 16-person index, fetches full profiles only when opened, supports recursive family navigation, and keeps visited content available after force-quit and relaunch.

## Run it

Requirements: Xcode 26 or newer and an iOS 17.0 or newer iPhone simulator.

1. Open `FamilySearch.xcodeproj`.
2. Select the `FamilySearch` scheme and an iPhone simulator.
3. Press Run.

There are no packages to install, generated files, API keys, or configuration changes. The app uses only Apple frameworks.

## What I decided and why

### MVVM with explicit boundaries

Views receive stable, initializer-injected `ViewModel` instances. They render exhaustive presentation state and forward taps; they do not know about URLs, DTOs, SwiftData, or cache rules. `@MainActor` observable view models turn domain values into small immutable presentation models. Repository protocols are the boundary between presentation and data.

The wire, domain, and persistence representations are deliberately separate. Private `Codable` DTOs mirror the service response, domain structs describe what features need, and SwiftData entities describe the local schema. That duplication is useful here: a service or storage change cannot silently become a UI change.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the dependency direction, responsibilities, concurrency model, and preview strategy.

### Cache-on-fetch, not a recursive download

The list endpoint is fetched as the one small collection the service provides. Full profiles are fetched lazily through the separate `/persons/{id}.json` endpoint only when a user opens one. Opening a relative therefore triggers that relative's profile request; the app does not crawl or download the family graph.

Each repository load follows the same policy:

1. Fetch the latest value from the API.
2. Persist the decoded domain value in SwiftData.
3. Read it back from SwiftData and return that stored value.
4. If the network fails, read the existing SwiftData value instead and mark it stale.
5. If neither network nor saved data is available, show the first-launch failure state.

Network values never bypass persistence on their way to the UI, so SwiftData remains the record source of truth online and offline. Portraits use the same cache-on-fetch idea with a durable file store because binary files and their eventual eviction policy are different from queryable records.

### SwiftData persistence

SwiftData provides a real schema-backed store without adding setup or a dependency. The concrete people repository is a `@ModelActor`, so it owns every `ModelContext` operation; person lookups use a predicate plus `fetchLimit = 1` rather than reading and scanning the whole collection.

List membership is stored separately from profile completeness. That lets a profile-only relative remain cached and directly queryable without leaking into the root list. A list refresh replaces membership while preserving already-fetched profile fields and relatives.

### Navigation and concurrency

The root `NavigationStack` carries only stable `PersonID` values. `RootView` constructs each profile view model with the shared people repository, which makes relative navigation recursive without coupling screens to persistence objects.

SwiftUI `.task` owns screen work, including retries, so disappearance cancels the load. Cancellation is preserved through URLSession; generation tokens prevent a late response from overwriting a newer load. UI-observed mutation stays on the main actor, while clients, repositories, portrait storage, and SwiftData access use actor isolation.

## States, previews, and tests

The list distinguishes loading, empty, fresh content, saved/stale content, and first-launch failure with retry. Its initial appearance loads through the repository; returning from navigation keeps the existing SwiftData-backed content, while pull to refresh explicitly requests fresh data without replacing the list with a full-screen spinner. Profiles distinguish loading, fresh content, saved/stale content, and failure. Missing portraits and optional fields have intentional fallbacks.

Data-displaying views have previews composed with the real view models and a seeded in-memory SwiftData container. Preview data includes a living person, nullable fields, relatives, and portraits; previews never call the network.

The 34 tests focus on places where defects would be expensive or subtle:

- service decoding, relative URL resolution, malformed data, HTTP/transport errors, and unsafe IDs;
- SwiftData round trips, direct lookup behavior, profile merging, list membership, and reopening a disk store;
- network-to-store behavior and offline fallback;
- view-model mapping, retry, cancellation, and stale-response protection;
- durable portrait reads and writes.

Manual QA was run on an iPhone 17 Pro simulator with iOS 26.5. Screenshots and the exact offline approach are in [docs/qa/README.md](docs/qa/README.md).

## Dependencies

None. SwiftUI, Observation, SwiftData, Foundation/URLSession, and UIKit cover the required behavior. A third-party package would add review and build risk without buying a meaningful capability at this size.

## Known gaps and tradeoffs

- Profile records have a fetched/not-fetched marker but no age or server-revision policy. A visited profile is refreshed whenever opened, then falls back to its saved copy.
- Portrait files do not yet have size accounting or eviction. Invalid image bytes are rejected before caching.
- Persistent-store creation is treated as an app invariant. A production app would surface store recovery or migration failure instead of terminating at startup.
- The UI prioritizes clarity and accessibility over custom visual polish.

## If the list were 100,000 people

The service contract would need pagination or incremental synchronization; the client should not request one enormous response. I would ingest pages in bounded batches and store revision/tombstone metadata so a sync can update membership without deleting cached profile details. List queries would page directly from SwiftData using indexed sort/search fields rather than materializing every row. Portrait storage would add byte budgets, last-access metadata, and eviction. The existing repository and model boundaries allow those changes without rewriting the views.

## With another day

I would add UI tests for the full online → force-quit → offline journey, store migration/recovery handling, portrait-cache eviction, Dynamic Type and VoiceOver passes, and lightweight request/refresh diagnostics. I would also add profile freshness metadata so refresh policy is explicit rather than always-on-open.

## Process

I used an AI assistant as an issue-driven implementation partner: I wrote an epic and dependency-ordered child issues, reviewed each issue's PR into an integration branch, ran focused tests after each layer, then performed simulator QA and an adversarial architecture review. The commit and PR history is intentionally part of the submission—it records the decisions, parallel work, integration fixes, and QA evidence rather than presenting the app as a single unexplained code drop.
