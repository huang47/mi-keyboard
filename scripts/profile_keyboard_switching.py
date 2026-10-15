#!/usr/bin/env python3
"""Profile real three-keyboard switching without XCTest/AX timing overhead.

Uses only a dedicated iPhone17Pro/iOS26.5 Simulator. All product instrumentation
and negative controls live in isolated copies; finally restores an unmodified app.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import statistics
import subprocess
import sys
import time

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'Tests/SwitchProfiling'
PRODUCT = ('App', 'Keyboard', 'KeyboardUI', 'Shared', 'Resources')
ROI = (430, 557, 10, 292)  # Letter rows, excluding the transient spacebar language label.
PIXEL_LIMIT = .5  # Mean absolute grayscale difference, out of 255.


def run(command, log, **kwargs):
    with Path(log).open('w') as output:
        subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, check=True, **kwargs)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def events(path):
    result = []
    for line in path.read_text().splitlines():
        try:
            item = json.loads(line)
        except ValueError:
            continue
        message = item.get('eventMessage', '')
        match = re.search(r'SWFULL t=([\d.]+) event=(\S+)\s*(.*)', message)
        if match:
            result.append({'time': float(match[1]), 'name': match[2], 'detail': match[3],
                           'pid': item['processID']})
    return result


def freeze(destination):
    destination.mkdir()
    for name in (*PRODUCT, 'Tests'):
        shutil.copytree(ROOT / name, destination / name)
    shutil.copy2(ROOT / 'project.yml', destination)
    return {str(f.relative_to(destination)): sha(f) for name in PRODUCT
            for f in (destination / name).rglob('*') if f.is_file()}


def patch(source, minimum=False, delay=0):
    for name in ['ProfileEvents.swift', 'ProcessStart.m']:
        shutil.copy2(FIXTURES / name, source / 'Keyboard' / name)
    shutil.rmtree(source / 'Tests/SwitchHost')
    (source / 'Tests/SwitchHost').mkdir()
    shutil.copy2(FIXTURES / 'Host.swift', source / 'Tests/SwitchHost/App.swift')
    controller = source / 'Keyboard/KeyboardViewController.swift'
    if minimum:
        shutil.copy2(FIXTURES / 'MinimumController.swift', controller)
    else:
        value = controller.read_text()
        changes = {
            '    private let keyboard = KeyboardView()': '''    private let keyboard: KeyboardView = {
        switchProfile("keyboard.construct.begin")
        let value = KeyboardView()
        switchProfile("keyboard.construct.end")
        return value
    }()''',
            '        super.viewDidLoad()': '        switchProfile("viewDidLoad.begin")\n        super.viewDidLoad()',
            '        keyboard.load(table: tableProvider())': '''        switchProfile("dictionary.load.begin")
        keyboard.load(table: tableProvider())
        switchProfile("dictionary.load.end")
        switchProfile("viewDidLoad.end")''',
            '            self?.keyboard.clearComposition()': '''            let touch = event.allTouches?.first
            switchProfile("globe.begin", "touch=\\(touch?.timestamp ?? -1) phase=\\(touch?.phase.rawValue ?? -1)")
            self?.keyboard.clearComposition()
            switchProfile("composition.clear.end")''',
            '            self?.handleInputModeList(from: sender, with: event)': f'''            if event.allTouches?.first?.phase == .ended {{ Thread.sleep(forTimeInterval: {delay / 1000}) }}
            self?.handleInputModeList(from: sender, with: event)
            switchProfile("globe.handler.return")''',
            '    override func viewWillLayoutSubviews()': '''    override func viewWillAppear(_ animated: Bool) {
        switchProfile("viewWillAppear.begin")
        super.viewWillAppear(animated)
        switchProfile("viewWillAppear.end")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switchProfile("viewDidAppear")
    }
    override func viewWillLayoutSubviews()''',
        }
        for old, new in changes.items():
            assert value.count(old) == 1, 'Update the profiling seam: ' + old
            value = value.replace(old, new)
        # Do not put even a zero-duration sleep into the ordinary timing control.
        if not delay:
            value = value.replace('            if event.allTouches?.first?.phase == .ended { Thread.sleep(forTimeInterval: 0.0) }\n', '')
        controller.write_text(value)
    project = (source / 'project.yml').read_text()
    if minimum:
        start = project.index('  BoshiamyKeyboard:')
        end = project.index('    settings:', start)
        project = project[:start] + '  BoshiamyKeyboard:\n    type: app-extension\n    platform: iOS\n    sources: [Keyboard]\n' + project[end:]
    project += '\n  SwitchProfileHost:\n    build:\n      targets:\n        KeyboardSwitchHost: all\n'
    (source / 'project.yml').write_text(project)


def build(source, derived, out, host=False):
    run(['xcodegen', 'generate'], out / (source.name + ('-generate-host.log' if host else '-generate.log')), cwd=source)
    command = ['xcodebuild', '-quiet', '-project', str(source / 'Boshiamy.xcodeproj'),
               '-scheme', 'SwitchProfileHost' if host else 'Boshiamy', '-configuration', 'Release',
               '-sdk', 'iphonesimulator', '-derivedDataPath', str(derived), 'build', 'CODE_SIGNING_ALLOWED=NO']
    run(command, out / (source.name + ('-build-host.log' if host else '-build.log')))
    return derived / 'Build/Products/Release-iphonesimulator' / ('KeyboardSwitchHost.app' if host else 'Boshiamy.app')


class Capture:
    def __init__(self, args, out):
        self.args, self.out, self.actions = args, out, []
        self.env = {**os.environ, 'DEVELOPER_DIR': subprocess.check_output(['xcode-select', '-p'], text=True).strip()}
        self.log = (out / 'events.ndjson').open('w')
        self.video_log = (out / 'video.log').open('w')
        self.hid_log = (out / 'hid.log').open('w')
        self.logs = subprocess.Popen(['xcrun', 'simctl', 'spawn', args.simulator, 'log', 'stream', '--level', 'debug',
                                     '--style', 'ndjson', '--predicate', 'subsystem == "com.shh.mi.switchprofile"'],
                                    stdout=self.log, stderr=subprocess.STDOUT)
        self.video = subprocess.Popen(['xcrun', 'simctl', 'io', args.simulator, 'recordVideo', '--codec=h264', str(out / 'screen.mov')],
                                     stdout=self.video_log, stderr=subprocess.STDOUT)

    def wait(self, predicate, timeout=10):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if predicate():
                return
            time.sleep(.02)
        raise RuntimeError('Missing real event or capture readiness')

    def touch(self, label, x, y, hold=.05, wait=.15):
        start = time.monotonic()
        subprocess.run([str(self.out / 'sim-hid'), self.args.simulator, str(x), str(y), str(hold)],
                       stdout=self.hid_log, stderr=subprocess.STDOUT, env=self.env, check=True)
        action = {'label': label, 'start': start, 'returned': time.monotonic()}
        self.actions.append(action)
        time.sleep(wait)
        return action

    def require(self, action, event, detail=None):
        self.wait(lambda: any(e['time'] >= action['start'] and e['name'] == event and
                             (detail is None or e['detail'] == detail)
                             for e in events(self.out / 'events.ndjson')))

    def screen_words(self, name):
        shot = self.out / (name + '.png')
        subprocess.run(['xcrun', 'simctl', 'io', self.args.simulator, 'screenshot', str(shot)], stdout=self.hid_log, stderr=subprocess.STDOUT, check=True)
        return [json.loads(line) for line in subprocess.check_output([str(self.out/'recognize'),str(shot)],text=True).splitlines()]

    def select(self, label, embedded=False):
        self.touch('openPicker', *( (78,770) if embedded else (42.7,840) ), 1.2, .2)
        rows = self.screen_words('picker-' + str(len(self.actions)))
        def normalized(text):
            return text.replace('键', '鍵').replace('盘', '盤').replace(' ', '')
        choices = {key: [r for r in rows if normalized(r['text']).startswith(key) and r['x'] < 195 and 400 < r['y'] < 800]
                   for key in ['English', 'Emoji', '米鍵盤']}
        if not choices['米鍵盤']:
            # With exactly EN/Emoji/Mi enabled, iOS labels the only custom row Chinese.
            # Vision can recognize this subtitle more reliably than the Han title.
            choices['米鍵盤'] = [r for r in rows if r['text']=='Chinese' and r['x']<195 and 400<r['y']<800]
        assert all(len(value)==1 for value in choices.values()), ('Not the real three-keyboard picker', rows)
        row = choices[label][0]
        return self.touch('select-' + label, row['x'], row['y'], wait=1.)

    def verify_text(self, key, points, expected):
        action = self.touch('verify-' + key, *points, wait=.15)
        self.require(action, 'editor.changed', 'value=' + expected)

    def kill_inactive(self):
        ps = subprocess.check_output(['ps', '-axo', 'pid=,args='], text=True)
        targets = [line.strip().split(None, 1) for line in ps.splitlines()
                   if '/Devices/' + self.args.simulator + '/' in line and
                   line.strip().endswith('/Boshiamy.app/PlugIns/BoshiamyKeyboard.appex/BoshiamyKeyboard')]
        assert len(targets) == 1, targets
        pid = int(targets[0][0])
        os.kill(pid, signal.SIGTERM)
        self.actions.append({'label': 'terminateInactiveExtension', 'time': time.monotonic(), 'pid': pid})
        time.sleep(.25)

    def stop(self):
        for process in [self.video, self.logs]:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
        for process in [self.video, self.logs]:
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.terminate()
        for stream in [self.log, self.video_log, self.hid_log]:
            stream.close()
        (self.out / 'actions.json').write_text(json.dumps(self.actions, indent=2) + '\n')


def analyze(out):
    records = events(out / 'events.ndjson')
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_frames', '-show_entries',
                                                 'frame=best_effort_timestamp_time', '-of', 'json', str(out / 'screen.mov')]))
    pts = np.array([float(frame['best_effort_timestamp_time']) for frame in metadata['frames']])
    tiles, clocks, present = [], [], []
    with (out / 'decode.log').open('w') as error:
        decoder = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', str(out / 'screen.mov'), '-vf', 'scale=302:656',
                                    '-fps_mode', 'passthrough', '-pix_fmt', 'gray', '-f', 'rawvideo', '-'], stdout=subprocess.PIPE, stderr=error)
        while True:
            data = decoder.stdout.read(302 * 656)
            if not data:
                break
            assert len(data) == 302 * 656
            frame = np.frombuffer(data, dtype=np.uint8).reshape(656, 302)
            present.append(55 < np.median(frame[146:151, 19:23]) < 100)  # Red sentinel.
            clocks.append(sum(1 << n for n in range(32) if np.median(frame[146:151, 32+n*6:35+n*6]) > 127) / 1000)
            tiles.append(frame[ROI[0]:ROI[1], ROI[2]:ROI[3]].copy())
        assert decoder.wait() == 0
    assert len(pts) == len(tiles) and np.all(np.diff(pts) >= 0)
    clocks, present = np.array(clocks), np.array(present)
    anchor = statistics.median(e['time'] for e in records)
    clocks += np.round((anchor - clocks) / (2**32 / 1000)) * (2**32 / 1000)
    assert present.sum() > 100, 'Missing rendered frame clock'
    offsets = clocks[present] - pts[present]
    assert np.quantile(offsets, .75) - np.quantile(offsets, .25) < .0167, 'Unstable frame-clock alignment'
    times = pts + np.quantile(offsets, .95)
    tiles = np.stack(tiles)
    actions = json.loads((out / 'actions.json').read_text())
    rows = []
    for action in actions:
        label = action['label']
        if label not in ['miToEnglish', 'englishToMiWarm', 'englishToMiCold']:
            continue
        start = action['start']
        following = [e for e in records if start < e['time'] < start + 2]
        down = next(e for e in following if e['name'] == ('globe.begin' if label == 'miToEnglish' else 'host.touch') and 'phase=0' in e['detail'])
        up = next(e for e in following if e['name'] == down['name'] and 'phase=3' in e['detail'])
        touch0 = float(re.search(r'touch=([\d.]+)', down['detail'])[1])
        touch1 = float(re.search(r'touch=([\d.]+)', up['detail'])[1])
        mode = next(e for e in following if e['name'] == 'inputModeChanged')
        ready = next(e for e in following if e['name'] == ('keyboardDidChangeFrame' if label == 'miToEnglish' else 'viewDidAppear'))
        next_start = min([a['start'] for a in actions if a.get('start', 0) > start] + [float(times[-1])])
        end = min(start + 1.1, next_start - .03, float(times[-1]) - .02)
        target = tiles[np.searchsorted(times, end - .05)].astype(float)
        indices = np.where((times >= touch0) & (times < end))[0]
        difference = np.mean(np.abs(tiles[indices].astype(float) - target), axis=(1, 2))
        matching, wrong = indices[difference < PIXEL_LIMIT], indices[difference >= PIXEL_LIMIT]
        assert len(matching)
        settled = int(wrong[-1] + 1) if len(wrong) else int(indices[0])
        index = max(settled, int(np.searchsorted(times, ready['time'])))
        assert index in indices and end - times[index] > .03 and difference[np.where(indices == index)[0][0]] < PIXEL_LIMIT
        row = {'route': label, 'touchDown': touch0, 'holdMs': (touch1-touch0)*1000,
               'modeChangedMs': (mode['time']-touch0)*1000, 'controllerReadyMs': (ready['time']-touch0)*1000,
               'firstMatchingFrameMs': float((times[matching[0]]-touch0)*1000),
               'readyFrameMs': float((times[index]-touch0)*1000), 'readyFrameIndex': index, 'touchProcessID':down['pid'], 'readyProcessID':ready['pid']}
        for name in ['process.constructor', 'keyboard.construct.begin', 'keyboard.construct.end', 'viewDidLoad.begin', 'viewDidLoad.end']:
            stage = next((e for e in following if e['name'] == name), None)
            if stage:
                row[name+'Ms'] = (stage['time']-touch0)*1000
        if label == 'englishToMiWarm':
            assert ready['pid']==rows[-1]['touchProcessID'], 'Unexpected fresh process in warm workload'
        if label == 'englishToMiCold':
            kill = next(a for a in reversed(actions) if a['label'] == 'terminateInactiveExtension' and a['time'] < start)
            assert ready['pid'] != kill['pid'] and any(e['name'] == 'process.constructor' and e['pid'] == ready['pid'] for e in following)
            row['oldPID'], row['newPID'] = kill['pid'], ready['pid']
        assert all(math.isfinite(value) for value in row.values() if isinstance(value, float))
        rows.append(row)
    groups = {}
    for label in ['miToEnglish', 'englishToMiWarm', 'englishToMiCold']:
        group = [row for row in rows if row['route'] == label]
        if not group:
            continue
        values = [row['readyFrameMs'] for row in group]
        groups[label] = {'count': len(values), 'medianMs': statistics.median(values), 'p95Ms': sorted(values)[math.ceil(.95*len(values))-1]}
    return {'samples': rows, 'groups': groups, 'alignmentOffsetQuantiles': [float(x) for x in np.quantile(offsets, [.25,.5,.75,.95,1])],
            'scope': 'Direct Simulator HID, including finger hold, process launch, controller-ready notification and stable destination pixels. Cached snapshots do not count as ready. +/- one display frame; not physical display latency.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--output', required=True, type=Path, help='Fresh evidence directory')
    parser.add_argument('--warm-iterations', type=int, default=5)
    parser.add_argument('--cold-iterations', type=int, default=5)
    parser.add_argument('--minimum-control', action='store_true', help='Nonfunctional lower-bound control; never shipped')
    parser.add_argument('--inject-exit-delay-ms', type=int, default=0, help='Negative control, in isolated copy only')
    args = parser.parse_args()
    assert args.warm_iterations >= 0 and args.cold_iterations >= 0 and args.warm_iterations + args.cold_iterations > 0
    assert args.inject_exit_delay_ms >= 0 and not (args.minimum_control and args.inject_exit_delay_ms)
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json']))
    runtime, device = next((runtime,d) for runtime,values in devices['devices'].items() for d in values if d['udid']==args.simulator)
    assert runtime.endswith('iOS-26-5') and device['deviceTypeIdentifier'].endswith('iPhone-17-Pro'), 'Pinned iPhone17Pro / iOS26.5 environment required'
    assert device['state'] == 'Booted' and device['name'] == 'Mi Keyboard Switch Latency'
    preferences = Path.home() / 'Library/Developer/CoreSimulator/Devices' / args.simulator / 'data/Library/Preferences/.GlobalPreferences.plist'
    enabled = plistlib.loads(preferences.read_bytes())['AppleKeyboards']
    assert len(enabled) == 3 and any(x.startswith('en_US@') for x in enabled) and any(x.startswith('emoji@') for x in enabled) and 'com.shh.boshiamy.keyboard' in enabled
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    original, measured = out / 'original', out / 'measured'
    hashes = freeze(original); shutil.copytree(original, measured); patch(measured, args.minimum_control, args.inject_exit_delay_ms)
    result = {'device': device, 'enabledKeyboards': enabled, 'productSourceSHA256': hashes,
              'runtime': runtime, 'harnessScriptSHA256': sha(Path(__file__)),
              'fixtureSHA256':{f.name:sha(f) for f in FIXTURES.iterdir() if f.is_file()},
              'minimumControl': args.minimum_control, 'injectedExitDelayMs': args.inject_exit_delay_ms,
              'budgetMs': {'warm': 200, 'coldNonRegression': 450, 'coldGoal': 200}}
    capture = None; restore_app = None
    try:
        restore_app = build(original, out/'original-derived', out)
        app = build(measured, out/'measured-derived', out)
        host = build(measured, out/'measured-derived', out, host=True)
        run(['xcrun','clang','-fobjc-arc','-fblocks','-framework','Foundation','-framework','AppKit',str(FIXTURES/'SimulatorHID.m'),'-o',str(out/'sim-hid')], out/'hid-build.log')
        run(['xcrun','swiftc','-parse-as-library',str(FIXTURES/'Recognize.swift'),'-o',str(out/'recognize')], out/'ocr-build.log')
        for bundle in [app, host]:
            subprocess.run(['xcrun','simctl','install',args.simulator,str(bundle)],check=True,capture_output=True)
        subprocess.run(['xcrun','simctl','terminate',args.simulator,'com.shh.boshiamy.switch-host'],capture_output=True)
        capture = Capture(args, out)
        subprocess.run(['xcrun','simctl','launch',args.simulator,'com.shh.boshiamy.switch-host'],check=True,capture_output=True)
        capture.wait(lambda: 'Recording started' in (out/'video.log').read_text(), 60)
        handshake = capture.touch('handshake', 114, 252, wait=.2)
        capture.require(handshake, 'cold.ready')
        capture.select('English')
        reference = json.loads((ROOT/'Tests/NativeEnglishKeyFrames.json').read_text())
        keyboard = next(c for c in reference['captures'] if c['name']=='portrait-uppercase' and c['screenWidth']==402)
        def key(label):
            k = next(k for k in keyboard['keys'] if k['label']==label); r=k['cap']; return (r['x']+r['width']/2,r['y']+r['height']/2)
        capture.verify_text('q', key('Q'), 'q'); capture.verify_text('delete', key('delete'), '')
        capture.select('米鍵盤')
        for cold in [False]*args.warm_iterations + [True]*args.cold_iterations:
            if not args.minimum_control:
                capture.touch('pending-h',*key('H'));capture.touch('pending-x',*key('X'))
            action = capture.touch('miToEnglish',78,770,wait=.65)
            capture.require(action,'globe.begin')
            capture.require(action,'inputModeChanged')
            capture.verify_text('q',key('Q'),'q'); capture.verify_text('delete',key('delete'),'')
            if cold:
                capture.kill_inactive()
            action = capture.touch('englishToMiCold' if cold else 'englishToMiWarm',42.7,840,wait=1.2)
            capture.require(action,'viewDidAppear')
            if not args.minimum_control:
                capture.touch('type-h',*key('H'));capture.touch('type-x',*key('X'))
                capture.verify_text('space',(202,779),'愛');capture.verify_text('delete',key('delete'),'')
        capture.select('Emoji', embedded=True)
        assert any('Search Emoji' in row['text'] for row in capture.screen_words('native-emoji')), 'Native Emoji not visible'
        capture.select('English')
        capture.verify_text('q',key('Q'),'q');capture.verify_text('delete',key('delete'),'')
        capture.stop(); capture = None
        result.update(analyze(out))
        for label,count in [('miToEnglish',args.warm_iterations+args.cold_iterations),('englishToMiWarm',args.warm_iterations),('englishToMiCold',args.cold_iterations)]:
            assert result['groups'].get(label,{}).get('count',0)==count, 'Missing attempted switch samples'
        result['passed'] = all(g['p95Ms'] <= (450 if label=='englishToMiCold' else 200) for label,g in result['groups'].items())
        result['cold200msGoalMet'] = result['groups'].get('englishToMiCold',{}).get('p95Ms',float('inf')) <= 200
        result['nativeEnglishOutputVerified'] = True
        result['chineseOutputAndCompositionCancellationVerified'] = not args.minimum_control
        result['threeRealPickerEntriesVerified'] = True
    except Exception as error:
        result.update(passed=False, error=str(error))
    finally:
        if capture:
            capture.stop()
        if restore_app:
            try:
                subprocess.run(['xcrun','simctl','install',args.simulator,str(restore_app)],check=True,capture_output=True)
                installed = Path(subprocess.check_output(['xcrun','simctl','get_app_container',args.simulator,'com.shh.boshiamy','app'],text=True).strip())
                binary = Path('PlugIns/BoshiamyKeyboard.appex/BoshiamyKeyboard')
                assert sha(installed/binary) == sha(restore_app/binary)
                result['unmodifiedAppRestored'] = True
                result['restoredExtensionSHA256'] = sha(installed/binary)
            except Exception as error:
                result.update(passed=False, unmodifiedAppRestored=False, restorationError=str(error))
        (out/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    for label,group in result.get('groups',{}).items():
        print(label, json.dumps(group))
    if args.cold_iterations:
        print('Cold 200ms goal:', 'NOT MEASURED' if 'cold200msGoalMet' not in result else 'MET' if result['cold200msGoalMet'] else 'NOT MET')
    print('PASS non-regression budgets' if result['passed'] else 'FAIL: '+str(result.get('error','latency regression')))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
