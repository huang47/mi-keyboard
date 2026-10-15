# Current XCUITest behavior coverage

The app and extension use only their own bundled dictionary. Dictionary updates ship as app updates; importing, restoring and sharing custom tables are removed.

```sh
xcodebuild -project Boshiamy.xcodeproj -scheme Boshiamy \
  -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' \
  -parallel-testing-enabled NO -only-testing:BoshiamyUITests test
```

The suite has 27 cases on iPhone 17 Pro/iOS 26.5; release evidence records case-level passes across the full run and a focused native-keyboard rerun after correcting editor visibility. Disconnect the simulator hardware keyboard and enable 米鍵盤 and English. The integration test can add the keyboard through Settings and never enables Full Access. System Files selectors are no longer needed; Settings/menu selectors use the simulator's English language.

| Behavior | Coverage |
| --- | --- |
| Bundled-only home and updates | No import/restore controls, correct bundled metadata, update explanation, persistence across process relaunch, HX → 愛 |
| Upgrade from an old custom table | A build 17 custom table is seeded before installing build 18. The new app and real extension must use the bundled table; no production code reads the legacy file |
| Setup and privacy | App Settings link/return, all five offline privacy sections, navigation back |
| Composition | Space/candidate/digit selection, unavailable digit no-op, zero literal commit, maximum length, editing/recovery, invalid composition blocks mode/Return/symbol insertion, raw long-press commit |
| Literal insertion | Idle Space/Return/numbers, commit before Return/symbol, held-number comma code |
| English and symbols | One-shot Shift, Caps Lock, unlock, single/double taps, case consumption, language switch commit, both symbol pages, punctuation, page reset, composition retention |
| Homophones | Seed query, resolution, blocked typing/literals/mode change, backspace/cancel, 瞎 → 蝦, normal typing afterward |
| Touch lifecycle | Held character commits once, drag-out cancels, gutter touch inserts once, held delete repeats and stops |
| Candidates and rotation | Scrolling/selecting from 1,000 candidates, scroll reset, rotation with pending composition, continued selection |
| Transient input | Leaving/reopening practice and relaunch clear output/composition; the bundled table remains available |
| Geometry | Independent native frames, portrait/landscape, stationary keys during composition, number row and functional controls |
| Actual extension | Real textDocumentProxy insertion/deletion and homophones, repeated native-English round trips, composition cancellation, system picker, native typing, rotation; App-only in-memory fixtures never override its bundled table |

Debug fixtures create only in-memory practice tables. They are compiled out of Release, write no files and do not affect the extension. Host editor focus checks its visible frame as well as isHittable, avoiding taps on a few exposed pixels after layout changes. Test cleanup resets orientation and terminates the app; failure screenshots/accessibility trees are retained.

39 Release tests complement UI coverage with engine, packed-dictionary corruption/canonical equality, candidate reuse, rendering and layout checks. Ten fixed-build-5 checks enforce correctness, no animation, glyph/cap dimensions and seven paired median/p95 workloads. Source/manifest and comparator bytes for build 5 remain unchanged. Timings describe synchronous simulator work, not physical touch latency.

Three focused iPad cases cover bundled-only home/relaunch, typing/mode switching and rotation. Full UI verification targets the established iPhone 17 Pro simulator; Pro Max cap/glyph dimensions have independent reference coverage in Release. This does not claim every OS/device/locale or physical-device execution.

## Version 1.0 (19)

Only version/build metadata changed. The 27 iPhone and three iPad cases are reused from build 18 with identical app, keyboard, engine and resource bytes. The Release suite (39) and fixed-baseline suite (10) were rerun for build 19. Product source checksums are recorded in [source-1.0.json](source-1.0.json).

## Version 1.0 (20): three real keyboards

The separate `KeyboardSwitchUITests` target adds three Release integration cases using English (US), Emoji and 米鍵盤. Its `KeyboardSwitchHost` is an autofocus native UITextField app with autocorrection off; it is excluded from the shipping app and archive. The cases cover all three real picker entries, native English insertion, composition cancellation and continued bundled-table input; 40 warm switch observations; and one externally prepared first activation with input verification. No mock keyboard or fake input proxy is used.

[Commands, all measurements and limits](SWITCH-LATENCY.md). These three cases, 39 Release unit cases and the ten fixed-build-5 checks passed. The existing 27-case main UI suite and three iPad cases retain their previous evidence; they were not rerun for this tests-only change. All 25 shipping app/keyboard/engine/resource source files match 1.0 (19); only build metadata changes to 20. The benchmark runner now retains the new test-only source references in its frozen project without adding them to the measured unit target.

## Native activation regressions

`ActivationTests` exercises the production input controller with the real packed dictionary: one installation per controller lifetime, composition cancellation and 100 ms app-owned activation budgets. It does not assert a native touch-to-display deadline. See [switch-speed evidence and remaining limits](SWITCH-SPEED.md).

## Version 1.0 (22): lean caption construction

42 Release unit cases, three native three-keyboard UI cases (including the new ten-sample short-tap budget), seven focused practice UI cases and ten fixed-build-5 checks passed. Startup checks now enforce Release median <= 11.75 ms and p95 <= 13.85 ms, plus all samples <= 100 ms. The caption regression checks first-use color/font and subsequent cache reuse. [Before/after data, scope and commands](SWITCH-IMPROVEMENT.md).

## Version 1.0 (23): full native handoff profiling

The separate [headless profiler](SWITCH-PROFILE.md) verifies real native English and Chinese output, cancellation, the three-entry picker and native Emoji, and measures retained/fresh-process activation through controller-ready recorded frames. It separates XCTest overhead and cached snapshots from actual controller readiness. The app's 25 shipping source/resource files match build 22. New fixture sources are excluded from shipping targets; temporary instrumented/minimum/delayed copies are restored afterward. The cold 200 ms target remains unmet.
