# Current keyboard structure

The keyboard uses the dictionary shipped with the app. Updating the app updates the dictionary; there is no custom import or restore workflow.

## Bundled dictionary path

- App and keyboard each load `boshiamy.bin` from their own bundle. A small process-local cache avoids decoding it again on every appearance.
- Removed the file picker, async import model, CIN/Rime/TSV parser, JSON decoder/writer, custom-table store, file-identity checks and import-specific errors.
- Removed App Group entitlements, shared-container configuration and Files sharing/open-in-place flags. Old custom files are never read; both the host app and extension use the bundled table after upgrade.
- `CodeTable` keeps input/candidate validation and derived metadata. Imported JSON schema/version/Codable support is gone. Independent canonical JSON decoding exists only in tests to verify packed data.
- Debug practice fixtures are in memory only. No files or shared tables are created by the current app.

## UIKit and engine responsibilities

`KeyboardView` coordinates actions and rendering. Concrete `KeyboardButton`, `KeyboardRow`, `KeyPreview` and candidate layout/cell types own their existing UIKit behavior in focused files. One page enum represents alphabet/first-symbol/second-symbol pages; one query enum holds normal/seed/resolved homophone state. Permanently hidden F/J marker layers and redundant row casts are removed.

Caption caches, bounded candidate frame caches and packed decoding remain because they support immediate updates and the permanent performance gate. No new protocols or dependency layers were introduced. The immutable shipped build 5 source, manifest and comparator transformation remain unchanged, including its historical import implementation solely for benchmark comparison.

See [tests](TESTING.md) and [performance gate](PERFORMANCE.md).
