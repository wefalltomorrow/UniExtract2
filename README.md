# Universal Extractor 2

[![Build](https://github.com/wefalltomorrow/UniExtract2/actions/workflows/build.yml/badge.svg)](https://github.com/wefalltomorrow/UniExtract2/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/wefalltomorrow/UniExtract2)](https://github.com/wefalltomorrow/UniExtract2/releases/latest)
[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](LICENSE)

Universal Extractor 2 is a Windows tool for unpacking archives, installers, disk images, self-extracting executables, game/resource packages and many other container formats through one interface.

This repository is a maintained community fork of [Bioruebe/UniExtract2](https://github.com/Bioruebe/UniExtract2). It carries forward the substantial 2026 work from [gvp9000/UniExtract2](https://github.com/gvp9000/UniExtract2) and adds further fixes, cleanup and release tooling here.

## Download

Use the [latest release](https://github.com/wefalltomorrow/UniExtract2/releases/latest).

The normal release ZIP contains the compiled UniExtract executables plus the helper-tool set needed by the current source. A standalone `UniExtract.exe` is also attached for the built-in updater.

Because UniExtract uses many third-party unpackers, antivirus products may occasionally flag one or more bundled tools. See [docs/ANTI-MALWARE.md](docs/ANTI-MALWARE.md) before reporting a detection.

## Highlights

Compared with the old upstream source, this fork includes:

- Detect It Easy as the primary executable detector, with Exeinfo PE and PEiD fallbacks
- newer handling for Inno Setup, InstallShield, WiX/Burn, Setup Factory, VISE/Gentee and NSIS installers
- updated integrations for 7-Zip, UnRAR, innounp, TrID, UPX, SQLite, lessmsi and other helpers
- improved batch queue, multipart archive and context-menu handling
- stricter corrupt-archive and wrong-password handling
- password-protected PDF extraction through qpdf
- ECM and ARJ Software JAR extraction support
- corrected FreeSpace / FreeSpace 2 VP folder extraction
- UTF-8 language-file support
- copied/quoted Windows path handling based on upstream PR #408
- quieter and more reliable `/silent` operation, including first-run behavior
- extension recovery for extracted MHTML content
- Unicode-path handling for split Inno Setup installers and their external `.bin` sidecars
- smarter QuickBMS/game detection, including safe silent-mode auto-selection when only one script matches
- Descent 3 HOG2 timestamp restoration after QuickBMS extraction
- more accurate extraction/pipeline result classification, including innounp output
- optional Game Extractor Basic fallback for obscure game archives that other handlers miss
- vgmstream r2117 game-audio fallback for selected proprietary formats, decoding one track to WAV when normal extraction routes fail
- acefile 0.6.14 bundled as a reproducibly built Windows x86 executable, with real ACE extraction regression coverage
- SHA-256-verified helper base plus complete packaged-bin and executable inventories for reproducible audits
- more useful extraction/pipeline logging

The full inherited history is in [docs/changelog.txt](docs/changelog.txt). The fork/PR/issue review behind this version is documented in [docs/FORK-NOTES.md](docs/FORK-NOTES.md).

## Updating and helper binaries

The source repository does not store the large third-party helper set directly.

The release package still uses gvp9000 v3.0.6 as a compatibility base for legacy helpers, but actively maintained tools are now refreshed by this fork's own reproducible packaging overlay. Downloads are pinned to known upstream packages and SHA-256 values where possible, then validated during the Windows CI build.

The old gvp9000 helper feed remains available only for helpers we have not moved into the overlay yet. Fork-managed helper paths are excluded from that feed so an older remote entry cannot downgrade them. See [docs/HELPER-AUDIT.md](docs/HELPER-AUDIT.md) for the current audit, refreshed tools and compatibility-pinned exceptions.

The source remains synced through gvp9000's v3.0.6 extraction changes from October 2, 2026, while keeping this fork's additional path, silent-mode, MHTML, Game Extractor, game-audio decoding and updater fixes. Bio.cs 2.6.0 is under compatibility testing and is **not** substituted for the existing bundled runtime.

The standalone updater downloads the current `UniExtract.exe` from this repository's latest GitHub release. There is not yet a separate nightly executable channel, so the nightly updater target currently falls back to the latest stable build.

Release packages preserve the third-party license material shipped with the helper bundle. Check those licenses before redistributing or using particular helpers in a commercial environment.

### Optional Game Extractor fallback

Game Extractor is supported as an **optional** low-priority game-archive backend. It is not bundled with the normal UniExtract package because the upstream download is large and includes its own Java runtime.

Install the public **Game Extractor Basic** package through UniExtract's Plugin Manager, or extract its `extract.zip` release into `bin\GameExtractor\`. UniExtract then tries it only after the existing dedicated handlers, GARbro/QuickBMS routes, extension routes and generic 7-Zip probe have failed.

Only the public Basic release should be used for redistribution/integration. Do not copy files out of the paid Full Version into a public UniExtract package. See [docs/GAME-EXTRACTOR.md](docs/GAME-EXTRACTOR.md) for details.

## Command line

Basic usage:

```text
UniExtract.exe <file> [<destination> | /scan | /sub | /last] [/silent] [/batch] [/type[=<type>]]
```

Examples:

```text
UniExtract.exe "C:\Downloads\setup.exe" "C:\Temp\setup"
UniExtract.exe "C:\Downloads\archive.zip" /sub /silent
UniExtract.exe "C:\Downloads\unknown.bin" /scan
```

See [docs/COMMAND-LINE.md](docs/COMMAND-LINE.md) for the complete switch reference.

## Building

The project is Windows-specific. The current source targets AutoIt 3.3.18.0.

Manual build:

1. Install [AutoIt](https://www.autoitscript.com/site/autoit/downloads/) and SciTE4AutoIt3.
2. Clone this repository.
3. Run `powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1`.

That builds:

- `UniExtract.exe`
- `UniExtractUpdater_NoAdmin.exe`
- `UniExtractUpdater.exe`

To create the full release package, run:

```powershell
.\scripts\package-release.ps1
```

The packaging script starts from the gvp9000 v3.0.6 full bundle as a legacy compatibility base, applies `scripts/refresh-helpers.ps1` to replace maintained helpers with pinned current builds, then overlays this fork's executables, definitions, languages, documentation and metadata. GitHub Actions performs the same build on Windows Server 2022, validates helper versions/hashes, and runs normal and Unicode-filename ZIP tests, an ADX-to-WAV decode through vgmstream, and real ACE integrity/extraction tests. A full per-file SHA-256 inventory and separate executable audit are produced with each packaged build.

## Contributing

Bug fixes, extractor improvements, format support, documentation and translation updates are welcome. Please keep changes focused and include a sample or reproducible test case when fixing an extraction problem.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the short contribution guide.

## Reporting problems

Open an [issue](https://github.com/wefalltomorrow/UniExtract2/issues) and include:

- the UniExtract version or commit
- the file/installer type
- what you expected
- what actually happened
- the generated UniExtract log, if available
- a public sample/download link when the file can legally be shared

## Credits

Universal Extractor was originally created by **Jared Breland**.

Universal Extractor 2 was developed by **Bioruebe** and contributors.

This fork also incorporates substantial later work by **gvp9000**, plus fixes and ideas from upstream pull requests, issue reporters, translators and other community forks. The individual extractor/helper programs remain the work of their respective authors.

See [docs/helper_binaries_info.txt](docs/helper_binaries_info.txt) and the third-party license files included in the full release package.

## License

Universal Extractor 2 is licensed under the **GNU General Public License v2**. See [LICENSE](LICENSE).

Bundled/helper tools have their own licenses and are not automatically covered by the UniExtract GPLv2 license.
