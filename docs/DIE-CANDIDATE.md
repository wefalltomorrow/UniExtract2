# Detect It Easy 3.21 candidate

Packaged UniExtract2 currently contains Detect It Easy files whose embedded PE metadata report 3.20.0.0. The latest tagged stable upstream Windows portable release is 3.21 (not the experimental 4.0 beta).

This branch deliberately does not replace the packaged `bin/die/` directory. The Windows candidate job retrieves pinned official 3.21 x86 and x64 portable ZIP files, validates their published SHA-256 digests, confirms the three main executables, compares the x64 executable hashes with those from the actual packaged UniExtract inventory, records embedded PE metadata, and runs the bundled CLI against a known Windows PE in a restricted PATH. **The official 3.21 x86 ZIP still embeds PE FileVersion 3.20.0.0**, so metadata alone is not evidence that a binary is older than the release tag.

Upstream hashes:

- 32-bit portable ZIP: `7d7195f757c45f6b69364d167c9958fa60339d53876a87e4a1edbcbf67d1e477`
- 64-bit portable ZIP: `078f2934f267392247f9c7b759a1c2457a48bc2000b25b80c2f129955ee4a3b9`

Only after candidate CI passes: compare packaged signatures, database folders and plugins, check compatibility with the AutoIt detector invocation and perform a full packaged UniExtract extraction regression test. Preserve existing 32-bit fallback. Do not merge this experiment into a release until that validation is complete.

Official upstream: https://github.com/horsicq/DIE-engine/releases/tag/3.21
