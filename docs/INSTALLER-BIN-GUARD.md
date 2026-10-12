# Installer BIN sidecar and GARbro false-positive regression

A large installer sidecar named setup-1.bin beside setup.exe was misrouted to GARbro in UniExtract 3.1.4. DiE and TrID reported FreeARC, but the broad GARbro probe ran first, recognised the data as PD/KAAS, and extracted 152 numbered entries with no explicit success confirmation.

Root-cause review of upstream GARbro's `ArcFormats/Kaas/ArcKAAS.cs` confirms that PD/KAAS has `Signature = 0`, normally registers only `.pd`, and constructs each numbered `basename#NNNN` entry from a permissively decrypted index. Those names are not filenames recovered from the original `.bin`. See https://github.com/morkt/GARbro/blob/master/ArcFormats/Kaas/ArcKAAS.cs. For `.bin` inputs, a PD/KAAS claim alone is now rejected as insufficient evidence.

This change preserves the original DiE FreeARC hint separately when Exeinfo replaces a weak result. On .bin inputs, it defers broad game extractors when a numbered sidecar has a same-base companion EXE or when independent DiE and TrID reports agree on FreeARC. Ordinary game archives and other extensions retain their existing routing. Later specific detector routes may attempt FreeARC/unarc.

The final pipeline records the actual GARbro or unarc extractor when successful rather than an earlier failed 7-Zip probe. Windows CI regression-tests the actual extracted AutoIt guard function against matching sidecar, unrelated .bin, two-detector FreeARC, one-detector-only, and non-bin cases.

The original 60 GB payload was not uploaded. Its standalone FreeARC validity remains unverified; the guard does not promise extraction of proprietary installer payloads. Keep the original source file and companion installer unchanged until this is checked.

## Verified third-party working unpacker (user-supplied, not bundled)

A `CODEX Unpacker.7z` supplied alongside the incident contains `unpack.exe`, `unarc.dll`, `config.ini`, `arc.ini`, and `Unpack.bat`. The user confirmed this tool successfully extracted the installer `setup*.bin` payload. Static inspection only (the executable was **not** executed):

- `unpack.exe`: 32-bit Windows executable, UPX-packed; SHA-256 `1f8186afecbf1ddc1c768b09dceecd6b9066bc8b12847becbc608c73c809281f`.
- `unarc.dll`: 32-bit FreeArc decompressor exporting `FreeArcExtract`; SHA-256 `461e262189717c32ef0d7b559137b4f37d0eea1f7010a564adb11a06927938c4`.
- `Unpack.bat`: launches `unpack config.ini`.
- `config.ini`: sets `InputFile=.\setup-1.bin`, `OutputPath=.\CODEX-DATA`, `Password=ABC`, `CfgFile=.\arc.ini`, and `WorkPath=.\temp`.
- `arc.ini`: contains only a semicolon.

This corroborates the **FreeArc/installer-data** diagnosis and suggests password-aware extraction is important. We have not proven the password is required by the original file (the provided configuration merely supplies it), nor that the stock bundled `unarc.exe` supports the same encryption/compression. The working third-party binary's provenance, license and trustworthiness are unknown. **Do not copy or automatically invoke either executable in production.**

A future separate opt-in FreeArc installer extraction path should prefer audited FreeArc tooling, accept a user-provided password without logging it, validate both the archive and resulting payloads, and never default to GARbro's signatureless PD/KAAS recognizer.
