# Architecture

## Dependency direction

```text
SwiftUI View → @MainActor ViewModel → Domain protocol ← Repository
                                                     ↙    ↓    ↘
                                              Remote DTO Store Portrait files
```

Dependencies point inward toward domain types. A view knows its view model; a view model knows domain models and repository protocols. Neither layer knows the service wire format or persistence schema.

## Responsibilities

### Views

Every SwiftUI screen or component ends in `View`. Feature views receive their view model through an initializer and keep that injected instance stable with SwiftUI state ownership. Views render exhaustive presentation states and forward user intent. They do not start URL requests, query SwiftData, map records, format domain records for display, or own cache policy. Navigation carries a stable `PersonID`, never a DTO or managed entity.

### View models

Every feature view model ends in `ViewModel` and is visibly injected into its view. View models are `@MainActor` observable reference types. They translate repository results into immutable presentation models and presentation state, handle user intents, and own screen-scoped request lifetime. Each load receives a generation token; a cancelled or superseded request cannot replace newer state. Cancellation is not presented as a user-facing failure.

### Domain

Domain structs express what the app needs without `Codable`, SwiftData annotations, or UI imports. `PeopleRepository` provides ordinary async load methods and returns a stored domain value plus an optional refresh issue. `PortraitRepository` is separate because binary storage and eviction have different concerns from record storage.

### Data implementations

SwiftData is the app's single source of truth. The concrete `LivePeopleRepository` is a `@ModelActor` that owns both synchronization and persistence: it asks the API adapter for domain values, saves them, and returns a fresh SwiftData query. Fresh network values do not bypass persistence on their way to a view model. This gives online and offline paths the same entity-to-domain mapping without a separate store abstraction.

Transport DTOs mirror JSON and exist only inside the remote adapter. SwiftData entities mirror the local schema and exist only inside the persistence adapter. A profile query is keyed by person ID rather than implemented as a full-table in-memory scan. Views and view models never receive a `ModelContext`, use `@Query`, or render persisted entities directly.

## Composition

`FamilySearchApp` constructs the two production repositories at startup and passes them to `RootView`. The root creates feature view models through explicit initializers. Tests replace repository protocols with deterministic fakes; views and view models do not reach into globals or SwiftData's environment.

## Previews

Views that display records include previews built through the same view-model injection path as the app. A preview composition factory creates an in-memory SwiftData `ModelContainer`, seeds representative entities—including living people, missing optional values, relatives, and cached portraits—and constructs the real local store/repository around that context. Preview fixtures never ship in the production container, and previews do not call the network.

## Concurrency and cancellation

- UI-observed mutation is isolated to `MainActor`.
- Repository protocols are `Sendable`; implementations protect mutable state with actors or framework-specific isolation.
- Structured `.task` work is cancelled when its view disappears.
- Cancellation propagates rather than becoming a generic error.
- A load generation prevents an older response from overwriting a newer retry.

## Deliberate tradeoffs

The app uses one app target rather than separate framework modules because the dependency rules are testable without adding unnecessary build complexity. Protocol seams preserve the option to extract modules later. SwiftData provides proportionate, schema-backed storage with no third-party setup; the repository prevents that choice from leaking into features.

## Readability

The code favors concrete names, small types, and direct control flow over clever abstractions. Comments explain architectural boundaries or decisions that are easy to misread—such as why fresh values are reread from SwiftData and why loads carry a generation—but do not narrate ordinary Swift syntax. This keeps the implementation practical to review and walk through.
