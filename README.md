# Universal Extractor 2

This is a maintained community fork of [Bioruebe/UniExtract2](https://github.com/Bioruebe/UniExtract2).

The goal is simple: keep UniExtract2 useful on current Windows versions and bring together worthwhile fixes that have ended up scattered across the original repository, open pull requests, issue discussions and active forks.

This fork currently builds on the large 2026 update set from [gvp9000/UniExtract2](https://github.com/gvp9000/UniExtract2), then adds extra fixes and cleanup here. The original Universal Extractor was created by Jared Breland, and UniExtract2 was developed by Bioruebe.

## What it does

Universal Extractor 2 tries to unpack files without requiring you to know which extraction tool they need first. It supports normal archives as well as many installers, disk images, self-extracting archives, game/resource formats and other containers.

It uses a collection of specialist tools behind one interface, with file detection deciding which extraction path to try.

## What is different in this fork

Compared with the last upstream source release, the current development branch includes a much newer extraction and detection pipeline, including:

- Detect It Easy as the primary executable detector with Exeinfo PE and PEiD fallbacks
- newer handling for Inno Setup, InstallShield, WiX/Burn, Setup Factory, VISE/Gentee and NSIS installers
- improved 7-Zip, UnRAR, lessmsi, QuickBMS and GARbro command handling
- more reliable batch queue handling, including duplicate and multipart-volume checks
- better silent/unattended extraction behavior
- stricter corrupt-archive and wrong-password handling
- password-protected PDF extraction through qpdf
- JAR (ARJ Software) and ECM extraction support
- improved FreeSpace / FreeSpace 2 VP extraction data
- UTF-8 language-file support
- updated helper-tool integration and file signatures
- fixes for paths containing spaces and copied/quoted Windows paths
- a more useful per-file extraction log and pipeline report

See [docs/changelog.txt](docs/changelog.txt) for the inherited change history and [docs/FORK-NOTES.md](docs/FORK-NOTES.md) for the upstream PR, issue and fork review used for this branch.

## Development status

The current work is on the `best-of-all` branch and is marked as **3.1.0 development**.

There is not yet a packaged release from this fork. Until one is published, treat the repository as source/development work rather than a drop-in replacement release.

### Updates and helper binaries

The source needs the external helper programs used by UniExtract2. For now this fork continues to use gvp9000's maintained helper-file update feed because it contains the newer extractor set this code expects.

Main executable updates from that feed are deliberately disabled. A helper update must never replace this fork's `UniExtract.exe` with another fork's build.

Once this fork has its own release/update bundle, those remaining helper URLs can be moved over as well.

## Upstream pull requests

The currently open pull requests in the original repository have been reviewed rather than blindly merged:

- **#408 – quoted/copied path handling:** included, with slightly more conservative trimming.
- **#342 – ASH, AP4, LZ7, TPL, U8 and WAD support:** useful idea, but the patch depends on several extra third-party executables that it does not package or manage. It is being kept as follow-up work instead of merging code that would advertise formats without shipping a working extraction path.
- **#432 – “Super sonic”:** unrelated to Universal Extractor and intentionally not included.

More detail is in [docs/FORK-NOTES.md](docs/FORK-NOTES.md).

## Building from source

1. Install [AutoIt](https://www.autoitscript.com/site/autoit/downloads/).
2. Install the AutoIt SciTE editor if you want the normal wrapper/build workflow.
3. Clone this repository.
4. Build `UniExtract.au3` with AutoIt3Wrapper/Aut2Exe.
5. Make sure the UniExtract helper files are present in the expected `bin`/support directories. The built-in helper updater can populate/update the supported helper set.

The project is Windows-specific and some extraction paths depend on third-party tools that are not stored directly in this source repository.

## Reporting problems

Please open an issue in this repository with:

- the UniExtract version/commit
- the file type or installer type
- what you expected to be extracted
- what actually happened
- the generated UniExtract log, when available
- a public sample or download link if the file can legally be shared

Issues: https://github.com/wefalltomorrow/UniExtract2/issues

## Credits

Universal Extractor was originally created by **Jared Breland**.

Universal Extractor 2 was developed by **Bioruebe** and its contributors.

This fork also incorporates substantial later work by **gvp9000** and fixes/ideas from upstream pull requests, issue reporters, translators and other community forks. Individual third-party extractors remain the work of their respective authors.

See [docs/helper_binaries_info.txt](docs/helper_binaries_info.txt) and the files under `docs/third-party` for third-party tool and license information.

## License

Universal Extractor 2 is licensed under the **GNU General Public License v2**. See [LICENSE](LICENSE).

The bundled/helper tools used by UniExtract2 have their own licenses. Some do not permit commercial use, so check the relevant third-party license before redistributing a complete binary package.
