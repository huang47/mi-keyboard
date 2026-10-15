# Fcitx5 Boshiamy data attribution

Source: https://github.com/fcitx/fcitx5-table-extra
Pinned revision: `dbc7154a7f0b9fc04313160ae8066ed4d8cbc446`.

The bundled data is converted from `tables/boshiamy.txt`, preserving every code and the order of candidates, deduplicating identical pairs. Upstream README states: “All the data file is now in public domain.” This is an upstream licensing declaration, not an independent determination of the legal status of every possible Boshiamy table. The implementation here is independently written in Swift; no Fcitx5/libime engine code is linked or copied.

The original data, README, configuration and upstream GPL license are retained for provenance. GPL applies to upstream code as stated in README; the code is not bundled into the executable. “Boshiamy / 嘸蝦米” identifies compatibility and does not imply endorsement by the original vendor.

Regenerate `Resources/boshiamy.json` with `python3 scripts/prepare_table.py`.
