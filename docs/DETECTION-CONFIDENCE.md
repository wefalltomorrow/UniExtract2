# Detection confidence policy

The extractor dispatch order is deliberately more conservative than older
UniExtract2 releases. A tool reporting "I found files" is evidence that the
tool *interpreted bytes*, not necessarily proof of the true archive format.

## Confidence hierarchy

1. **Verified binary signature**: recognised exact headers at fixed byte
   offsets (currently FreeArc, 7z, ZIP, RAR, gzip, bzip2, xz, PDF, PNG,
   JPEG, GIF, Ogg, FLAC, EBML, MP4, WAV, AVI, WebP). The filename extension
   cannot override this evidence.
2. **Matching dedicated handlers**: UnRAR, ZIP, PDF and other native handlers
   may still run when the extension agrees with a verified header.
3. **Specific archive definition**: a user-supplied format handler or an
   extension-matched script in the BMS registry may run before a general
   archive probe, *unless* a conflicting verified header exists.
4. **General archive probing**: 7-Zip comes before permissive ISO and game
   scanners. An exact archive header that 7-Zip cannot extract is reported
   as unsupported/corrupted, not reclassified as a game archive.
5. **Heuristic game fallback**: GARbro, QuickBMS, TotalObserver, and optional
   Game Extractor are tried only when stronger evidence has not excluded them.
   The QuickBMS family requires a positive file-list count without tool
   errors, and GARbro refuses uncorroborated PD/KAAS when input is not .pd.

A successful output directory alone is not a trustworthy identifier of
file type. The report records a verified-header winner separately from the
tool which actually extracted files. Later heuristic hints must not overwrite
the verified-header classification.

## Compatibility limits

The signature table is intentionally small. A missing entry means
*unverified*, not that a file is invalid. Self-extracting PE installers,
legacy game archive formats and extension-specific scripts retain their
existing paths where no trusted header conflicts.

Some authentic archives are identified correctly but still cannot be
extracted by the installed helper, for example custom FreeArc repack codecs.
A correct format identification is not a promise that the available
decompressor supports every variant.

Heuristic extractors may still misinterpret unknown or signatureless file
types; no finite signature list can prove every proprietary game archive.
The new policy prevents high-confidence contradictions and requires
positive listing evidence rather than claiming universal format certainty.

## Automated coverage

- `tests/installer-bin-guard.ps1`: FreeArc / PD-KAAS regression, including
  native .pd and unrelated .bin/.dat/.zip inputs.
- `tests/detection-confidence.ps1`: 24 short binary prefixes, renamed files,
  negatives and malformed QuickBMS listings, run by the actual AutoIt interpreter.
- `scripts/smoke-test.ps1`: packaged app tests for normal/Unicode ZIP,
  audio/ACE, FreeArc false positives, genuine ZIP masquerading as .bin,
  and a PNG prefix misleadingly named .zip.

CI must finish building and running packaged smoke tests before merging
this policy into the published version.
