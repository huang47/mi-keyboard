# Third-party data and notices

The MIT license at the repository root applies to this project's original code and documentation. It does not replace third-party terms or grant rights to third-party trademarks.

## Fcitx5 community character-code data

- Source: https://github.com/fcitx/fcitx5-table-extra
- Pinned revision: `dbc7154a7f0b9fc04313160ae8066ed4d8cbc446`.
- Bundled source: `ThirdParty/Fcitx5/boshiamy.txt`; generated forms: `Resources/boshiamy.json` and `Resources/boshiamy.bin`.
- Upstream README declares its data files public domain. This is the upstream declaration, not an independent legal determination about other or official Boshiamy tables.
- The original README, provenance, settings and upstream GPL text are retained in `ThirdParty/Fcitx5/`.
- No Fcitx5/libime engine code is linked or copied into this independently implemented Swift engine. Upstream's GPL code license is not being replaced by this project's MIT license.

## Unicode pronunciation data

- Source: Unicode 17.0.0 `Unihan_Readings.txt`, fields `kMandarin` and `kHanyuPinyin`.
- Source archive: https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
- Source, license and notices: `ThirdParty/Unicode/`.
- Generated index: `Resources/homophones.json`.
- License: Unicode License V3. The copyright and permission notice is retained in `ThirdParty/Unicode/LICENSE.txt` and bundled as `Resources/Unicode-LICENSE.txt`.
- Unicode readings include regional and historical pronunciations; this is not the official Boshiamy homophone dictionary.

The performance baseline is this project's own historical Swift implementation from shipped build 5, retained unchanged for comparison. It is not Fcitx5/libime source code.
