#!/usr/bin/env python3
"""Run a frozen Release A/B keyboard benchmark; fail before archiving regressions."""
import argparse
import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "Tests/PerformanceBaseline/build5"
BASELINE_MANIFEST_SHA = "81b9de9bbfb7bc0b7bbad318a978f69d687cdbbeeae596d72821d4082605339b"
LIMIT = 1.05
WORKLOADS = {
    "visible_candidate_7_type_delete", "visible_candidate_1000_type_delete",
    "visible_changing_candidate_lists_1000", "visible_real_dictionary_hx_a",
    "visible_cold_first_type_after_table_load", "visible_symbol_toggle_pair", "visible_english_once_type_delete",
}
BASELINE_NAMES = ("KeyboardView", "CompositionEngine", "CodeTable", "TableError", "TableParser", "TableStore", "TableJSON", "PackedCodeTable")


def namespaced_baseline(file):
    source = file.read_text()
    for name in BASELINE_NAMES:
        source = re.sub(r"\b" + name + r"\b", "Baseline" + name, source)
    return source


def digest(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def verify_baseline():
    assert digest(BASELINE / "manifest.json") == BASELINE_MANIFEST_SHA, "Baseline manifest changed"
    manifest = json.loads((BASELINE / "manifest.json").read_text())
    for name, expected in manifest["sha256"].items():
        assert digest(BASELINE / name) == expected, "Build 5 baseline changed: " + name
    return manifest


def check(action, snapshot, output):
    reference = verify_baseline()
    manifest = json.loads((snapshot / "manifest.json").read_text())
    assert manifest["baselineManifestSha256"] == BASELINE_MANIFEST_SHA, "Wrong baseline"
    for name, expected in manifest["sha256"].items():
        assert digest(snapshot / name) == expected, "Frozen source changed: " + name
    for file in BASELINE.rglob("*.swift"):
        assert (snapshot / "Tests" / ("Baseline" + file.name)).read_text() == namespaced_baseline(file), "Comparator was retargeted: " + file.name
    log = json.loads(action.read_text())
    assert log["result"] == "succeeded", "XCTest did not succeed"
    strings = []

    def walk(value):
        if isinstance(value, str):
            strings.append(value)
        elif isinstance(value, dict):
            for item in value.values():
                walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)

    walk(log)
    text = "\n".join(strings)
    assert "PERF_SEMANTICS passed" in text, "Missing correctness checks"
    metrics, samples = {}, {}
    for line in re.findall(r"PERF_COMPARE [^\n]+", text):
        parts = line.split()
        values = {k: float(v) for k, v in (part.split("=", 1) for part in parts[2:])}
        assert all(math.isfinite(v) and v > 0 for v in values.values()), "Invalid timings"
        if parts[1] in metrics:
            assert metrics[parts[1]] == values, "Conflicting benchmark results"
        metrics[parts[1]] = values
    for line in re.findall(r"PERF_SAMPLES [^\n]+", text):
        _, name, values = line.split(" ", 2)
        samples[name] = json.loads(values)
    assert set(metrics) == WORKLOADS and set(samples) == WORKLOADS, "Missing workloads"
    regressions = []
    for name, values in metrics.items():
        raw = samples[name]
        assert set(raw) == {"baseline", "current", "pairedRatios"}, "Missing raw samples"
        for timings in raw.values():
            assert len(timings) == 41 and all(math.isfinite(v) and v > 0 for v in timings), "Invalid samples"
        assert abs(sorted(raw["pairedRatios"])[20] - values["paired_median_ratio"]) < 1e-8
        assert abs(sorted(raw["current"])[38] / sorted(raw["baseline"])[38] - values["p95_ratio"]) < 1e-8
        for statistic in ("paired_median_ratio", "p95_ratio"):
            if values[statistic] > LIMIT:
                regressions.append({"workload": name, "statistic": statistic, "ratio": values[statistic]})
    result = {
        "reference": reference["version"], "noiseTolerancePercent": 5,
        "samplesPerWorkload": 41, "alternatingOrder": True,
        "snapshot": str(snapshot.resolve()), "sourceSha256": manifest["sha256"],
        "baselineManifestSha256": BASELINE_MANIFEST_SHA,
        "metrics": metrics, "rawSamples": samples, "regressions": regressions,
        "passed": not regressions,
        "scope": "Simulator main-thread work including synchronous layout and CATransaction.flush; excludes physical touch-to-display latency.",
    }
    output.write_text(json.dumps(result, indent=2) + "\n")
    for name, values in metrics.items():
        print(f"{name}: median ratio {values['paired_median_ratio']:.3f}; p95 ratio {values['p95_ratio']:.3f}")
    print("PASS" if result["passed"] else "FAIL: performance regression")
    return result["passed"]


def run(simulator, output_directory, source_root):
    verify_baseline()
    output_directory.mkdir(parents=True, exist_ok=False)
    snapshot = output_directory / "source"
    snapshot.mkdir()
    for name in ("App", "Keyboard", "KeyboardUI", "Shared", "Resources"):
        shutil.copytree(source_root / name, snapshot / name)
    tests = snapshot / "Tests"
    tests.mkdir()
    shutil.copy2(ROOT / "Tests/PerformanceRegressionTests.swift", tests)
    shutil.copy2(ROOT / "Tests/PerformanceTests.swift", tests)
    shutil.copy2(ROOT / "Tests/NativeEnglishKeyFrames.json", tests)
    for file in BASELINE.rglob("*.swift"):
        (tests / ("Baseline" + file.name)).write_text(namespaced_baseline(file))
    project = (source_root / "project.yml").read_text()
    start = project.index("  BoshiamyTests:")
    end = project.index("  BoshiamyUITests:", start)
    target = project[start:end]
    target = re.sub(r"    sources:.*\n", "    sources: [Tests, Shared, KeyboardUI, Resources]\n", target)
    project = project[:start] + target + project[end:]
    project = project.replace("targets: [BoshiamyTests, BoshiamyUITests]", "targets: [BoshiamyTests]")
    # The UI target is not built by this scheme; retain its source reference for XcodeGen.
    shutil.copy2(ROOT / "Tests/UITests.swift", tests)
    project = project.replace("sources: [Tests, Shared, KeyboardUI, Resources]", "sources:\n      - path: Tests\n        excludes: [UITests.swift]\n      - Shared\n      - KeyboardUI\n      - Resources")
    (snapshot / "project.yml").write_text(project)
    subprocess.run(["xcodegen", "generate"], cwd=snapshot, check=True, capture_output=True)
    manifest = {
        "frozenAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "baselineManifestSha256": BASELINE_MANIFEST_SHA,
        "sha256": {str(f.relative_to(snapshot)): digest(f) for f in snapshot.rglob("*") if f.is_file()},
    }
    (snapshot / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    bundle = output_directory / "Performance.xcresult"
    command = ["/usr/bin/xcodebuild", "-quiet", "-project", str(snapshot / "Boshiamy.xcodeproj"),
               "-scheme", "Boshiamy", "-configuration", "Release", "-destination", "platform=iOS Simulator,id=" + simulator,
               "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
               "-derivedDataPath", str(output_directory / "derived"), "-resultBundlePath", str(bundle),
               "-only-testing:BoshiamyTests/PerformanceRegressionTests",
               "-only-testing:BoshiamyTests/PerformanceTests/testKeyPreviewTracksCaptionStaysInsideKeyboardAndDoesNotInterceptTouches",
               "-only-testing:BoshiamyTests/PerformanceTests/testCompositionAndCandidateTextUpdatesDoNotAnimate",
               "-only-testing:BoshiamyTests/PerformanceTests/testShiftAndCapsLockUpdatesDoNotFade",
               "-only-testing:BoshiamyTests/PerformanceTests/testSymbolPagesUpdateWithoutAnimations",
               "-only-testing:BoshiamyTests/PerformanceTests/testSameCountCandidateReplacementUpdatesWidthsTextAndSelection",
               "-only-testing:BoshiamyTests/PerformanceTests/testReferenceLayoutPreservesCaseHeightAndSpacebarTouches",
               "-only-testing:BoshiamyTests/PerformanceTests/testEveryKeyMatchesMeasuredNativeEnglishDimensions",
               "-only-testing:BoshiamyTests/PerformanceTests/testNativeGlyphBoundsMatchReference", "test"]
    with (output_directory / "xcodebuild.log").open("w") as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    action = output_directory / "action.json"
    with action.open("w") as log:
        subprocess.run(["/usr/bin/xcrun", "xcresulttool", "get", "log", "--path", str(bundle), "--type", "action"], check=True, stdout=log)
    return check(action, snapshot, output_directory / "results.json")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", help="Booted simulator UDID")
    parser.add_argument("--source", type=Path, default=ROOT, help="Product source directory to freeze and measure")
    parser.add_argument("--output", type=Path, required=True, help="Fresh output directory for a run, or results JSON for --check")
    parser.add_argument("--check", nargs=2, metavar=("ACTION_JSON", "SNAPSHOT"), type=Path)
    args = parser.parse_args()
    if args.check:
        return check(*args.check, args.output)
    if not args.simulator:
        parser.error("--simulator is required for a benchmark run")
    return run(args.simulator, args.output.resolve(), args.source.resolve())


if __name__ == "__main__":
    try:
        sys.exit(0 if main() else 1)
    except (AssertionError, subprocess.CalledProcessError, OSError, ValueError, KeyError) as error:
        print("Performance gate blocked: " + str(error), file=sys.stderr)
        sys.exit(1)
