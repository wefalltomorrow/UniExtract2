# Helper binary audit

Last reviewed: 2026-10-10

Universal Extractor relies on a large set of third-party command-line tools, libraries and format plugins. This fork does not treat "newest source commit" as automatically safer than the existing binary: helper replacements need a usable Windows build, compatible architecture, suitable redistribution terms and a repeatable validation path.

## Refreshed for v3.1.3

The release package still starts from the gvp9000 v3.0.6 helper bundle for legacy compatibility, then `scripts/refresh-helpers.ps1` overlays actively maintained helpers from pinned upstream packages.

The v3.1.3 overlay refreshes and validates:

- 7-Zip 26.04, x86 and x64
- qpdf 12.4.2, MinGW x86 package
- UPX 5.2.1
- Asar7z 1.5, x86 and x64
- eDecoder 1.20.8, x86 and x64
- Iso7z 1.8.7, x86 and x64
- Py7z 1.2.1, x86 and x64
- MediaInfoLib 26.10, x86
- Exeinfo PE 0.1.0.0, isolated under `bin\Exeinfo\`
- Champollion 1.3.2
- PEA 1.33 from PeaZip 11.3.0
- GNU gettext `msgunfmt` 1.0, static x86
- innounp 2.71.1
- TrID definitions dated 2026-10-08, 22,425 definitions
- UnRAR 7.23 x64
- CHDMan 0.289 x64
- SQLite 3.53.4: x86 shell plus x86/x64 DLLs

The refresh script pins SHA-256 values for downloaded release material, checks reported versions where practical, verifies the refreshed 7-Zip format plugins are actually loaded, and writes `HELPER-REFRESH.txt` into the packaged build.

### Next-release utilities (not included in v3.1.3)

The next helper overlay adds the tagged vgmstream **r2117** Windows x86/x64 CLI bundles, each SHA-256 pinned. UniExtract tries vgmstream only for a short allowlist of proprietary game-audio extensions, after normal archive and Game Extractor routes have failed. The initial decoder exports a single, non-looped WAV, not every subsong of a bank. See [VGMSTREAM.md](VGMSTREAM.md).

The same development overlay also adds acefile 0.6.14 as a frozen x86 console utility. Neither it nor vgmstream should be described as present in the published v3.1.3 package. Both require release-specific Windows CI confirmation before tagging.

## Already current or intentionally unchanged

The following notable helpers were reviewed and do not need a normal release bump at this time:

- Detect It Easy 3.21: latest published stable Windows release. A newer version number appears in upstream development sources, but there is no newer stable Windows release package yet.
- GARbro 1.5.44: latest official release.
- Game Extractor Basic 3.16.0008: latest public Basic release and remains optional.
- lessmsi 2.12.9: latest official release.
- Qt Linguist 5.15.18: current Qt 5 Windows package used by this project. Upstream also publishes a Qt 6 build, but switching branches provides no extraction benefit here.
- QuickBMS 0.12: current public release used by the existing integration.
- ZPAQ 7.15: current release used by the package.

Many other UniExtract helpers are old because the underlying utility itself is old or abandoned. An old date by itself is not a reason to replace a specialist extractor that still covers formats newer general-purpose tools do not.

## Compatibility-pinned exceptions

Some helpers have newer source releases but no straightforward newer binary that preserves UniExtract's current compatibility requirements.

### lzip

UniExtract keeps lzip 1.22 because that remains the latest official standalone Windows binary published by the project. Newer source releases exist, but replacing it with an environment-dependent third-party build would be a different packaging decision.

### CHDMan x86

Modern MAME releases no longer publish a 32-bit Windows build. v3.1.3 refreshes the x64 CHDMan to 0.289 and keeps the historical x86 copy for 32-bit Windows compatibility.

### UnRAR x86

Current Windows distribution is x64-focused. v3.1.3 refreshes the x64 UnRAR path to 7.23 while retaining the previous x86 helper for 32-bit compatibility.

### Neko runtime

The Neko runtime exists only to support older Haxe-built helper programs in this package. Neko itself is deprecated, and changing the runtime without format-specific regression samples risks breaking those helpers for no direct extraction gain. It remains compatibility-pinned.

## Legacy helper feed

The fork still uses gvp9000's helper update feed for legacy helpers that have not yet moved into our own overlay. Files managed by the v3.1.3 overlay are explicitly excluded from that feed so an older remote entry cannot downgrade them.

This is an intermediate step toward owning the complete helper bundle and update metadata in this fork.

## Automated complete file inventory (unreleased development)

The Windows packaging process generates **BIN-INVENTORY.csv** directly from the fully populated staged `bin` folder, after the maintained helper overlay has run. Every file, including nested DLLs, runtime support files, format plugins and legacy command-line programs, receives an actual SHA-256 digest, size, path and available embedded version and PE architecture information.

A separate **BIN-INVENTORY-SUMMARY.txt** reports the totals and how many files remain in the inherited, not-yet-individually-reviewed group. The additional **BIN-EXECUTABLES.csv** focuses specifically on packaged `.exe` utilities, with a separate count of remaining legacy executables. This prevents the thousands of inherited runtime and data files from obscuring the actual tool updates. Required 7-Zip, qpdf, SQLite, CHDMan, UnRAR, TrID and vgmstream files must be present for the package to pass.

This is a **complete file listing**, not a claim that every tool is current or has passed extraction regression tests. Source/review labels differentiate fork-pinned updates, explicit compatibility exceptions and legacy entries still requiring upstream checking.

### Newly checked utilities

- **acefile 0.6.14 (next release, pending Windows CI)**: replaces 0.6.11 with a self-contained x86 EXE built from a SHA-256-pinned PyPI source tarball using Python 3.12 x86 and PyInstaller 6.22.3. CI verifies its command-line version and tests a real upstream ACE archive with an independently checked Git blob hash. Source: https://pypi.org/project/acefile/
- **Bio.cs 2.5.0**: upstream tagged **2.6.0** (March 2024). No prebuilt release asset was found; a rebuilt DLL would need compatibility testing against dependent Bioruebe extractors before it replaces `Bio.cs.dll`. Source: https://github.com/Bioruebe/Bio.cs/releases
- **File/libmagic 5.46**: a newer upstream 5.48 exists; replacing `file.exe` also requires a matching `magic.mgc` compiled database and Windows/x86 compatibility validation. Treat these as one coupled update, not independent files. Upstream: https://github.com/file/file ; package versions: https://anaconda.org/conda-forge/libmagic
- **innoextract 1.9**: matches the latest upstream tagged release; retain: https://github.com/dscharrer/innoextract/releases
- **Forensic7z 1.6**: matches the currently published plugin version; retain: https://www.tc4shell.com/en/7zip/forensic7z/
- **ExFat7z 1.1**: matches the author's current plugin release; retain: https://www.tc4shell.com/en/7zip/exfat7z/
- **Xpdf command-line utilities 4.06**: the current stable upstream release; retain: https://www.xpdfreader.com/download.html
- **TrID 2.48 and 2026-10-08 definitions**: match the published versions and definitions from Marco Pontello; retain: https://mark0.net/software-e.html
- **mtee 2.7**: matches the latest GitHub release; retain: https://github.com/isanych/mtee/releases
- **Unshield 1.6.2**: matches the latest tagged release; retain: https://github.com/twogood/unshield/releases
- **Bioruebe godotdec 2.1.2, cicdec 3.0.1, rmvdec 2.2.0, spoondec 2.0.1, utagedec 1.0.0**: match their published upstream release tags; retain these implementations unless format-specific regression evidence calls for a change.


## Release policy

A helper is a good candidate for refresh when all of the following are true:

1. there is a newer stable upstream release,
2. a compatible Windows binary can be obtained or reproducibly built,
3. redistribution is permitted,
4. UniExtract's invocation still works,
5. the package can be version/hash validated in CI, and
6. the change does not unnecessarily drop x86 or legacy-format compatibility.

For the exact files and shipped versions, see `docs/helper_binaries_info.txt`.
