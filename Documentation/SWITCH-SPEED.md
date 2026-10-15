# Native keyboard switching: build 21

The native English requirement is retained. The embedded globe continues to call Apple's `handleInputModeList(from:with:)` with the real touch events, including the long-press system picker. There is no in-keyboard English replacement, private API, forced language selection, or animation override.

## Change and regression tests

The immutable bundled dictionary is now installed once in `viewDidLoad`, rather than reinstalled on every `viewWillAppear`. This retains the existing controller's candidate/layout caches on reappearance. Composition is still cancelled before handing the real globe event to iOS and when the controller disappears. A recreated controller loads its own dictionary normally; process-local packed-table caching is unchanged.

`ActivationTests` uses the production `KeyboardViewController`, real dictionary decoding and real UIKit layout. Its replaceable table provider counts installations while returning the real bundled table. Before the fix, the reactivation regression failed: 42 dictionary installations instead of one. After the fix, all 41 Release unit tests passed with no failures/skips.

Two budgets are explicit:

- 21 controller constructions, each with a fresh real dictionary decode, view activation, layout and `CATransaction.flush`: every sample must be finite, positive and <= 100 ms. This does not assert that filesystem or OS caches are cold.
- 41 reappearances with pending composition: the dictionary installs once, composition cancels without a space, A + Space still produces 對, and the maximum measured reappearance work must be <= 100 ms.

| App-owned measurement | Before median / p95 ms | After median / p95 ms | After maximum ms |
| --- | ---: | ---: | ---: |
| Activation with fresh dictionary decode (n=21) | 14.270 / 15.935 | 13.073 / 15.384 | 68.528 |
| Reappearance + layout + transaction flush (n=41) | 0.081 / 0.242 | 0.031 / 0.060 | 3.362 |

These are separate runs and descriptive observations, not a statistically established improvement in end-to-end native switching. The deterministic regression is the removal of repeated dictionary installation. Neither row includes touch injection, iOS process scheduling, native keyboard rendering or physical display time.

```sh
xcodebuild -project Boshiamy.xcodeproj -scheme Boshiamy \
  -configuration Release -destination 'platform=iOS Simulator,id=<UDID>' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:BoshiamyTests/ActivationTests test
```

## What the earlier 459 ms means

Build 20's ten embedded-globe samples had automation-observed median 458.8 ms / p95 471.8 ms. The XCTest `tap()` call alone had median 389.8 ms. Subtracting that median would not produce a valid physical latency measurement.

Temporary timing probes in the actual extension and native test host recorded ten real touch-to-input-mode-notification transitions before optimization: 73.5–86.6 ms from the first touch event, and 6.8–19.9 ms from the final touch event. They retained the original monotonic touch timestamps; the host reported `en-US`. The app's globe clear/forward callback was below 0.1 ms in these observations. First dictionary acquisition took about 6.2 ms and warm acquisition plus installation about 0.2 ms. These figures explain why removing app-owned work cannot justify a claimed 459→100 ms end-to-end improvement.

The notification signals a changed input mode, **not a completely rendered native keyboard**. The exploratory run's Xcode diagnostic collector stalled and was stopped; these partial probes do not count as a passed whole UI run. The temporary probes were removed. Original events, limits and before/after unit samples are retained in [raw evidence](switch-speed-1.0-build21.json).

## 200 / 100 ms outcome

App-owned activation and reactivation meet their 100 ms regression budget on this simulator. **Native touch-to-display <= 200 ms or <= 100 ms has not been verified.** The app-owned improvement does not establish the cause of slow switching on a physical device, and no fix is claimed for the earlier SwiftUI editor / UIKit task-queue waits.

Apple selects the next user-enabled keyboard. Its public API provides no destination argument or completion/deadline control: [advanceToNextInputMode](https://developer.apple.com/documentation/uikit/uiinputviewcontroller/advancetonextinputmode%28%29). The system owns the cross-process handoff and native keyboard rendering. A physical-device trace or synchronized display capture remains necessary before making a touch-to-display claim.

The two three-real-keyboard integration cases passed again on the installed Release 1.0 (21) extension, with binary checksum verified. All 40 warm observations were retained. The embedded-globe automation series (n=10) was median **454.4 ms**, p95 **475.6 ms**; English→米鍵盤 picker selection (n=5) was 436.9 / 439.4 ms. These remain XCTest/AX timings and do not demonstrate a meaningful improvement over build 20. The separately prepared first-activation UI case was not rerun; its build-20 evidence is historical.

The [three-real-keyboard tests](SWITCH-LATENCY.md) and permanent fixed-build-5 engine/rendering guard remain separate requirements.
