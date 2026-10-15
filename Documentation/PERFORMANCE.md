# Keyboard performance baseline and release gate

The permanent reference is shipped **0.1.0 (5)**, before the top-text animation change. Its original keyboard and shared engine source live in `Tests/PerformanceBaseline/build5`; the manifest checksum is pinned in `scripts/check_keyboard_performance.py`. Generated comparator names are the only source transformation. The checker rejects a retargeted comparator even if snapshot hashes are recomputed.

Run before archiving any keyboard or engine change:

```sh
python3 scripts/check_keyboard_performance.py --simulator <booted-UDID> --output build/performance-<unique-name>
```

`--source <directory>` measures a frozen product snapshot. Each run freezes product source, generated project, tests and comparator; the result records their SHA-256. Archive the same product bytes. Passing a benchmark on an earlier source does not qualify a later change.

Seven workloads run visibly in a UIKit window in Release: 7/1000-candidate type/delete, changing 1000-candidate lists, real `HX Space A Space`, first `H` after table load, a symbol-page toggle pair, and English mode / one uppercase letter / delete / Chinese mode. Each alternates baseline/current order for 41 samples, with 20 repetitions per sample (5 for first-type and symbols). Warm-up is excluded. The first-type workload resets the view/table cache; it does not measure process launch or dictionary disk decoding.

Both the median paired ratio and p95 ratio must be **<= 1.05**. The 5% allowance accounts for measurement noise; it is not a claimed speedup. p95 is the percentile of batch-average operation times, not the tail of individual physical keystrokes. Raw samples are retained. Missing/nonfinite timings, failed correctness tests, changed source and a changed baseline block the gate. The real sequence must produce `愛對`, and synthetic workloads must update and clear the expected composition/candidates. Animation, actual visible upper/lowercase captions, candidate reuse, and font checks also run.

The measurement includes main-thread processing, synchronous UIKit layout and `CATransaction.flush()`. It excludes physical touch delivery, display scheduling and touch-to-photon latency. Native/iAcces parity still needs an on-device comparison.


## Version 1.0 (19)

All seven paired median/p95 workloads and ten fixed-baseline checks passed for the frozen 1.0 product source. [Sanitized results](performance-1.0.json) contain metrics and raw samples without private build paths or store records.
