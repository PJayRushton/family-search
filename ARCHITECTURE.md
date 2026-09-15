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

Views render exhaustive presentation states and forward user intent. They do not start URL requests, query SwiftData, map records, or own cache policy. Navigation carries a stable `PersonID`, never a DTO or managed entity.

### View models

View models are `@MainActor` observable reference types. They translate repository snapshots into presentation state and own screen-scoped request lifetime. Each load receives a generation token; a cancelled or superseded request cannot replace newer state. Cancellation is not presented as a user-facing failure.

### Domain

Domain structs express what the app needs without `Codable`, SwiftData annotations, or UI imports. `PeopleRepository` streams cached and refreshed domain snapshots so cache policy remains outside presentation. `PortraitRepository` is separate because binary storage and eviction have different concerns from record storage.

### Data implementations

The concrete repository owns remote/cache selection. Transport DTOs mirror JSON and map explicitly into domain models. SwiftData entities mirror the local schema and map explicitly into the same models. A profile query is keyed by person ID rather than implemented as a full-table in-memory scan.

## Composition

`AppContainer` is the composition root. It constructs concrete dependencies once and creates feature view models through explicit initializers. Tests replace protocols with deterministic fakes; views and view models do not reach into globals or SwiftData's environment.

## Concurrency and cancellation

- UI-observed mutation is isolated to `MainActor`.
- Repository protocols are `Sendable`; implementations protect mutable state with actors or framework-specific isolation.
- Structured `.task` work is cancelled when its view disappears, and repository streams cancel producers on termination.
- Cancellation propagates rather than becoming a generic error.
- A load generation prevents an older response from overwriting a newer retry.

## Deliberate tradeoffs

The app uses one app target rather than separate framework modules because the dependency rules are testable without adding build complexity to a four-hour exercise. Protocol seams preserve the option to extract modules later. SwiftData is planned for proportionate, schema-backed storage with no third-party setup; the repository prevents that choice from leaking into features.
