# Fork notes

Last reviewed: 2026-10-02

This file records where the current fork changes came from and what was deliberately left out. It is meant to stop fixes from getting lost in a long fork chain.

## Base used for this branch

- Original project: `Bioruebe/UniExtract2`
- Last upstream master commit reviewed: `9719ac988421e48276420e2f33e09087cfbacf8d` (2024-07-06)
- Main active fork used as the newer source base: `gvp9000/UniExtract2`
- gvp9000 head used as the starting point: `71f2efe262f19439cdc5ef2611b6ed7a742a5f64` (2026-09-04)

The gvp9000 fork was 97 commits ahead of the upstream master used here. Its commit messages are not always descriptive, so the source changes and changelog were reviewed rather than relying on commit titles.

## Upstream pull requests

### #408 - Remove noise that might wrap filenames

**Included.**

The upstream patch fixes paths copied from Windows Explorer's "Copy as path" command. This fork uses a conservative version of the same fix: trim outer whitespace, then remove one matching pair of surrounding quotes.

### #342 - ASH, AP4, LZ7, TPL, U8 and WAD support

**Reviewed, not merged yet.**

The patch adds routing for several Wii/archive formats, but it also depends on extra executables such as `unap4.exe`, `ash.exe`, `sharpii.exe` and `wwcxtool.exe`. The PR does not add a complete helper download/update/licensing path for them.

Merging the source-only part would make the program claim support that a normal installation could not actually provide. This should be integrated together with the required helpers and license/download metadata.

### #432 - Create Super sonic

**Not included.**

The PR only adds an unrelated remote Roblox/Lua loader and has nothing to do with Universal Extractor.

## Fork review

The actively changed forks visible from the upstream network were checked for unique work.

### gvp9000/UniExtract2

This is the only fork found with a large, current source change set. Useful work inherited from it includes:

- Detect It Easy integration and improved detector routing
- newer Inno Setup handling
- InstallShield and WiX/Burn extraction improvements
- Setup Factory / VISE / Gentee routing fixes
- lessmsi, QuickBMS and GARbro command compatibility updates
- batch queue locking, duplicate handling and multipart archive handling
- improved silent/password behavior
- stricter corrupt archive handling
- password-protected PDF extraction through qpdf
- ECM and JAR (ARJ Software) support
- UTF-8 translation support
- updated helper/signature integration
- FreeSpace / FreeSpace 2 VP QuickBMS data fix

Fork-specific branding and main-update behavior were not kept unchanged.

### mzelivsky-spec/UniExtract2

The only unique recent change found was an empty `.github/workflows/main.yml`. There was no code or build logic to carry over.

### StanleyKid-22/UniExtract2

Contains a corrected-encoding Ukrainian translation. The later gvp9000 source already records and contains that translation work, so no separate merge was needed.

### MinTurk/UniExtract2

Contains a 2026 Turkish translation commit on top of a much older source history. It was not copied wholesale because the language file predates many newer strings/format changes. It should be reconciled against the current Turkish file rather than replacing it blindly.

### Other updated/pushed forks checked

The other recently pushed forks reviewed either matched the old upstream head or mirrored older gvp9000 work without additional source changes. No separate code was taken from them.

## Upstream issue coverage

These are not being marked "closed" here because many reports require the original sample files for confirmation. The current fork contains code/helper changes that address or materially improve the following areas:

| Upstream issue | Status in this fork |
| --- | --- |
| #443 Silent mode displays GUI | Additional fix added here: first-run assistant, tray icon/status overlay and interactive repair are suppressed in silent mode. Existing error dialogs already have silent guards. |
| #207 Silent mode prompts | Improved by the gvp9000 unattended/password work plus the extra silent-mode fixes above. |
| #217 Batch queue ignores files | gvp9000 queue locking, pop-before-launch, duplicate-file handling and silent propagation are included. |
| #440 FreeSpace VP folder structure | gvp9000 supplied a corrected `BMS.db`; the upstream reporter confirmed it restored directory structure. This lives in the helper/update bundle rather than this source-only repository. |
| #416 Inno Setup 6.4.2 | The newer helper set uses a much newer `innounp` and updated Inno routing/probing. |
| #417 Exeinfo PE crash on Windows 11 ARM64 | DiE is now the primary detector and Exeinfo PE is a fallback, reducing dependence on the crashing path. This still needs ARM64 sample testing before calling it fully resolved. |
| #395 / #379 / #373 InstallShield extraction | InstallShield detection/fallback handling was substantially reworked, including CAB/HDR handling and stage-2 payload extraction. |
| #350 Setup Factory | Targeted Setup Factory detection/fallbacks are included before broad archive probing. |
| #329 Unsupported Nullsoft installer | NSIS routing and generic 7-Zip fallback behavior were reworked. Specific installer samples should still be retested. |
| #374 Update 7-Zip | The maintained helper set uses a current 7-Zip generation rather than the old upstream binary. |
| #406 7-Zip vulnerability report | Same helper refresh removes dependence on the years-old upstream 7-Zip build. |
| #354 WiX/Dark errors | WiX/Burn detection and Dark handling were reworked and updated. |
| #308 MHTML output missing .html extension | Added an MHTML-specific post-processing pass that uses the existing TrID extension recovery on extracted files. |
| #242 Original extension left changed after failed analysis | Current code analyses a temporary copied/renamed file instead of renaming the original input, avoiding the original failure mode. |

## Changes added specifically in this fork

- integrated upstream PR #408 path cleanup
- restore missing extensions after MHTML extraction (#308)
- fixed first-run GUI appearing during `/silent`
- hide the tray icon and extraction status overlay during `/silent`
- avoid interactive missing-file repair dialogs during `/silent`
- changed repository/home/help links to `wefalltomorrow/UniExtract2`
- disabled main executable replacement from the borrowed gvp9000 helper feed
- pointed the standalone updater's main executable URLs at this fork
- corrected the About dialog license text to GPLv2
- removed active use of gvp9000-specific About branding while retaining source credit

## Still worth doing

- package and test a complete release from this fork
- move the helper/update bundle to this fork once release hosting is ready
- integrate upstream PR #342 together with its required helper tools, licensing and update metadata
- add repeatable extraction regression samples for Inno, InstallShield, NSIS, Setup Factory, MSI/WiX, multipart archives, password-protected archives and PDFs
- add a Windows build/syntax check in GitHub Actions once the AutoIt build environment is pinned
