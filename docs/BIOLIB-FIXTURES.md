# Bio.cs client compatibility milestone

This development suite does not change release packaging. Bio.cs 2.5 and the
published helper set remain the stable baseline. The candidate restores the old
CLR overloads, DefaultOptions metadata and net40 target; extraction is tested
separately from those API checks.

## Reproduce on Windows

Use Python 3.12, .NET SDK 8 and Windows PowerShell 5.1. Obtain the v3.1.10 release
ZIP from this repository and verify SHA-256
`aee84c26e5f6321e3fb5fed6722a183d7ad4f71a8bae056144cd7b782084cf5d`.
Extract it into `.build/baseline`, then run:

```powershell
./scripts/build-biolib-compat.ps1
./tests/biolib-legacy-client.ps1 -BaselineDll .build/baseline/bin/Bio.cs.dll -CandidateDll .build/biolib-validation/bundle/bin/Bio.cs.dll
python tests/biolib-extractors.py --bin .build/baseline/bin --candidate .build/biolib-validation/bundle/bin/Bio.cs.dll --expect-godot-corruption --output .build/extractor-negative
./scripts/build-godotdec-compat.ps1 -BaselineDll .build/baseline/bin/Bio.cs.dll
python tests/biolib-extractors.py --bin .build/baseline/bin --candidate .build/biolib-validation/bundle/bin/Bio.cs.dll --godot-candidate .build/godotdec-validation/bundle/godotdec.exe --output .build/extractor-repaired
```

Without either Godot option, the suite requires correct output from the exact
shipped binaries and fails on the known Godot corruption. The negative-control
option requires that specific corruption; it does not accept arbitrary errors.
Its JSON records `correct: false` and `expected_corruption: true` separately from
the assertion result. The repaired run must produce correct output everywhere.

The workflow runs 17 cases with each of two libraries in each mode: 68 process
runs total, including eight explicit corruption reproductions. Every client and
non-framework DLL is pinned in `tests/biolib-client-pins.json`. The repaired Godot
executable is built against the original Bio.cs 2.5, then run unchanged with
both libraries. The report records both library hashes and the Godot hash.

## Known-output coverage

| Client | Generated successful fixtures | Failure fixture |
| --- | --- | --- |
| godotdec 2.1.2 | PCK v1, empty/nested files, Unicode names, embedded package offsets, Ogg conversion | Invalid magic |
| cicdec 3.0.1 | Installer v20 stored and zlib/deflate payloads | Missing overlay signature |
| rmvdec 2.2.0 | Directory input, explicit 16-byte key, header XOR and trailing bytes | Missing key for invalid input |
| sgbdec 2.0.0 | Legacy ZIP wrapper and current archive/file transforms, empty/nested files | Invalid magic |
| simdec 1.0.0 | Configuration, runtime cabinet/license rename, data cabinet and file list | Invalid footer |
| spoondec 2.0.1 | LZMA blocks, installer script and nested destination | No LZMA signature |

All test directories contain spaces, Japanese characters and an ampersand.
Fixtures contain synthetic data only. Expected content is defined independently
of extraction output. The harness checks the exact output file set and SHA-256
of every file, exit status, and baseline/candidate equivalence. Standard output
and error are retained for diagnosis; their text is not the correctness oracle.
Each process has a 20-second timeout and runs without a visible window.

## Godot defect and isolated repair

The published Godot binary calls `StreamExtensions.WriteToFile` after seeking
to the entry payload. Bio.cs 2.5 and 2.6 both rewind the stream in that method.
Consequently, a nonempty extracted file contains the beginning of the archive
instead of its payload; the client still prints `All OK` and exits zero.

`build-godotdec-compat.ps1` applies one behavioral change to the pinned 2.1.2
source: use `WriteToFileRelative`, which preserves the selected offset. The
candidate is labeled `2.1.2-ue2.1` (assembly/file version 2.1.2.1), retains net40,
and includes the upstream license. Both source archives are SHA-256 checked
before extraction. This repair is an isolated artifact, not a stable update.

Fixture design used upstream source and shipped-artifact checks:

- Godot 2.1.2: `475b61673189ef3ae5f759111f91cbda1dabde83`.
- cicdec, rmvdec and spoondec: their public Bioruebe repositories, with declared
  versions checked against the pinned published executables.
- sgbdec and simdec: static inspection of the exact pinned binaries and ILSpy
  9.1.0.7988 reconstruction, followed by the execution checks above. These are
  format fixtures written for this suite, not copied decompiler output.

## Remaining promotion gates

This finite suite is not proof of complete format or API compatibility. It does
not cover every Clickteam version, multi-volume cabinets, damaged/truncated
payloads, overwrite prompts, all conversion types, path traversal, large files,
or a machine with only .NET Framework 4.0 installed. The existing public API
comparison still excludes complete optional defaults/custom modifiers/generic
constraints. Do not promote Bio.cs merely because these fixtures pass.

Stable changes need a separate packaging change, the complete Windows package
tests and verification of the downloaded release artifact. The Godot repair can
be promoted independently while retaining Bio.cs 2.5.
