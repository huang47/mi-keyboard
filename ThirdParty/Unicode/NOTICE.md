# Unicode pronunciation data

Offline homophone lookup uses Unicode 17.0.0 Unihan_Readings.txt, fields kMandarin and kHanyuPinyin. Tone marks remain significant; a polyphonic seed searches each recorded reading. Groups contain single characters available in the bundled Fcitx5 Boshiamy table and preserve deterministic Unicode order, with the selected seed first. Unihan includes regional and historical readings; this is not the official Boshiamy pronunciation dictionary or a Taiwan-only pronunciation standard.

- Source archive: https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
- Field definitions: https://www.unicode.org/reports/tr38/
- License: https://www.unicode.org/license.txt (Unicode License V3, retained in LICENSE.txt and bundled Resources/Unicode-LICENSE.txt)
- Unihan_Readings.txt SHA-256: 575e69c9ad85a4737a889a4f94cbd987042a90a1a6cc16dd3f4ed995c715b17c
- Rebuild offline: python3 scripts/prepare_homophones.py

No definitions, translation data or source-engine implementation are used. Both the containing app and keyboard bundle the generated index; no network or full access is needed for queries.
