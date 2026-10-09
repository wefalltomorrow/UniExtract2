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
- vgmstream r2117: x86/x64 game-audio CLI decoders and their adjacent runtime DLLs

The refresh script pins SHA-256 values for downloaded release material, checks reported versions where practical, verifies the refreshed 7-Zip format plugins are actually loaded, and writes `HELPER-REFRESH.txt` into the packaged build.

### Game-audio utility added after v3.1.3

The next helper overlay adds the tagged vgmstream **r2117** Windows x86/x64 CLI bundles, each SHA-256 pinned. UniExtract tries vgmstream only for a short allowlist of proprietary game-audio extensions, after normal archive and Game Extractor routes have failed. The initial decoder exports a single, non-looped WAV, not every subsong of a bank. See [VGMSTREAM.md](VGMSTREAM.md).

This is a post-v3.1.3 change and should only be described as shipped once a new release's Windows CI and packaged smoke tests pass.

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

### acefile

The bundled `acefile.exe` is older than the current acefile Python source. The upstream project does not publish a matching current standalone Windows executable through its release page. Updating it would require maintaining our own packaged Python executable and regression-testing ACE extraction, so it is deferred rather than silently swapping implementations.

### CHDMan x86

Modern MAME releases no longer publish a 32-bit Windows build. v3.1.3 refreshes the x64 CHDMan to 0.289 and keeps the historical x86 copy for 32-bit Windows compatibility.

### UnRAR x86

Current Windows distribution is x64-focused. v3.1.3 refreshes the x64 UnRAR path to 7.23 while retaining the previous x86 helper for 32-bit compatibility.

### Neko runtime

The Neko runtime exists only to support older Haxe-built helper programs in this package. Neko itself is deprecated, and changing the runtime without format-specific regression samples risks breaking those helpers for no direct extraction gain. It remains compatibility-pinned.

## Legacy helper feed

The fork still uses gvp9000's helper update feed for legacy helpers that have not yet moved into our own overlay. Files managed by the v3.1.3 overlay are explicitly excluded from that feed so an older remote entry cannot downgrade them.

This is an intermediate step toward owning the complete helper bundle and update metadata in this fork.

## Release policy

A helper is a good candidate for refresh when all of the following are true:

1. there is a newer stable upstream release,
2. a compatible Windows binary can be obtained or reproducibly built,
3. redistribution is permitted,
4. UniExtract's invocation still works,
5. the package can be version/hash validated in CI, and
6. the change does not unnecessarily drop x86 or legacy-format compatibility.

For the exact files and shipped versions, see `docs/helper_binaries_info.txt`.
