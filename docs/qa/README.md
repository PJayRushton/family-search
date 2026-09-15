# QA evidence

Validated on 14 September 2026 with Xcode 26.6 and an iPhone 17 Pro simulator running iOS 26.5.

| Scenario | Evidence |
| --- | --- |
| Online list | [people-list.png](people-list.png) |
| Profile loaded from the separate profile endpoint | [person-profile.png](person-profile.png) |
| Relative selected and loaded as another profile | [relative-profile.png](relative-profile.png) |
| Force-quit and deterministic offline relaunch with saved data | [offline-relaunch.png](offline-relaunch.png) |
| Empty-store first launch while offline, including retry | [first-launch-offline.png](first-launch-offline.png) |

The offline runs use the Debug-only `FAMILY_SEARCH_FORCE_OFFLINE=1` process environment flag. It swaps only the records transport for a failing implementation, leaving the production repository and persistence paths unchanged. This tests the same failure boundary without disabling the developer machine's network.

The integrated suite passed 34 tests with zero failures. Coverage includes decoding and mapping, HTTP and transport errors, cancellation, stale-cache fallback, disk persistence, profile merging, profile-only list membership, cyclic navigation, view-model state transitions, explicit refresh behavior, and portrait caching.
