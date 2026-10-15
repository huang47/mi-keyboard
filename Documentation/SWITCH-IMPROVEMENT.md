# Build 22: faster keyboard construction

The Release controller startup median fell from **13.09 to 10.70 ms (18.3%)** and p95 from **15.40 to 13.03 ms (15.4%)** on the same iPhone 17 Pro / iOS 26.5 Simulator. Each run constructs 21 production controllers, freshly decodes the real packed dictionary, activates and lays out the keyboard, then flushes the rendering transaction. OS/filesystem caches are not asserted cold. This measures app-owned startup work, not complete native switching or physical touch-to-display time.

## Change and comparison

`KeyboardButton` creates its second caption only when first needed, then caches it for subsequent case changes. It also avoids allocating an unused inherited title label. Font, color, key frames, hit areas, immediate highlight feedback and native globe actions are retained. First lowercase use now verifies the lazily created caption inherits its color and remains cached.

| Same-device Release run | Median | p95 |
| --- | ---: | ---: |
| Original build 21 implementation | 13.09 ms | 15.40 ms |
| Candidate, repeat | 10.66 ms | 13.12 ms |
| Original restored as reverse control | 13.06 ms | 15.31 ms |
| Final build 22 | 10.70 ms | 13.03 ms |

The first sample remains included in every run; final maximum was 66.30 ms. The release regression checks require all 21 samples <= 100 ms, median <= 11.75 ms and p95 <= 13.85 ms. Tight timing assertions run only in Release; Debug explicitly skips them. Reactivation still checks one dictionary installation per controller and composition cancellation.

An experiment replacing the globe's system button with a custom button failed to improve short taps (447.60 to 464.36 ms median) and was reverted. Only `KeyboardButton.swift` changes shipping behavior compared with build 21; the other 24 shipping source/resource files match. Native English, Emoji and the system picker remain available.

## Three real keyboards

The real extension and a separate native UITextField host use exactly English (US), Emoji and 米鍵盤, with Full Access off and the Simulator hardware keyboard disconnected. Forty warm observations use the previous build's gestures, preparation and AX readiness checks. The added focused case repeats ten embedded-globe short taps, five with each native predecessor, and retains raw samples before timing assertions.

| Embedded globe, Mi to native English | Median | p95 |
| --- | ---: | ---: |
| Build 21 full-series reference (10) | 454.42 ms | 475.64 ms |
| Build 22 full series (10) | 446.86 ms | 460.89 ms |
| Build 22 focused regression (10) | 438.36 ms | 449.36 ms |

Whole-switch observations include XCTest injection, idle waits and accessibility queries. These modest differences are observations, not evidence that reducing Mi startup speeds up switching away to English. The focused regression caps median at 477.1 ms and p95 at 499.4 ms (+5% from build 21). The 200/100 ms native end-to-end goal is not established by this instrumentation. A physical device is not a prerequisite for this Simulator improvement task.

[All raw samples, rejected experiments and budgets](switch-improvement-1.0-build22.json) · [Shipping source hashes](source-1.0-build22.json) · [Original commands and measurement boundaries](SWITCH-LATENCY.md).

## Verification

Final build 22: 42 Release unit tests and three native three-keyboard UI cases passed, with no failures or skips. Seven focused practice UI cases cover captions, native reference geometry, shift/caps lock, landscape, held/dragged keys, gutters and candidate/mode changes. The permanent build 5 gate checks all seven workloads, correctness and no-animation behavior with paired median and p95 ratios <= 1.05. Historical full 27-case iPhone and three-case iPad results retain their original scope; they were not rerun in full for build 22. Test hosts and timing fixtures are excluded from the archive.
