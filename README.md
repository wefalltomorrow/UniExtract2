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
- more useful extraction/pipeline logging

The full inherited history is in [docs/changelog.txt](docs/changelog.txt). The fork/PR/issue review behind this version is documented in [docs/FORK-NOTES.md](docs/FORK-NOTES.md).

## Updating and helper binaries

The source repository does not store the large third-party helper set directly.

For the moment, helper-file updates continue to use gvp9000's maintained helper feed because that feed matches the modern extractor set inherited by this fork. Main-executable replacement from that feed is deliberately disabled so it cannot overwrite this fork with another build.

The standalone updater downloads the current `UniExtract.exe` from this repository's latest GitHub release. There is not yet a separate nightly executable channel, so the nightly updater target currently falls back to the latest stable build.

Release packages preserve the third-party license material shipped with the helper bundle. Check those licenses before redistributing or using particular helpers in a commercial environment.

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

The packaging script uses the gvp9000 v3.0.4 full bundle as the current helper-binary base, then overlays this fork's compiled executables, definitions, languages, documentation and metadata. The GitHub Actions workflow performs the same build on Windows Server 2022.

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
