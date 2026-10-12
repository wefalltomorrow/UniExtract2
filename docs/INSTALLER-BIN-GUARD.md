# Installer BIN sidecar and GARbro false-positive regression

A large installer sidecar named setup-1.bin beside setup.exe was misrouted to GARbro in UniExtract 3.1.4. DiE and TrID reported FreeARC, but the broad GARbro probe ran first, recognised the data as PD/KAAS, and extracted 152 numbered entries with no explicit success confirmation.

This change preserves the original DiE FreeARC hint separately when Exeinfo replaces a weak result. On .bin inputs, it defers broad game extractors when a numbered sidecar has a same-base companion EXE or when independent DiE and TrID reports agree on FreeARC. Ordinary game archives and other extensions retain their existing routing. Later specific detector routes may attempt FreeARC/unarc.

The final pipeline records the actual GARbro or unarc extractor when successful rather than an earlier failed 7-Zip probe. Windows CI regression-tests the actual extracted AutoIt guard function against matching sidecar, unrelated .bin, two-detector FreeARC, one-detector-only, and non-bin cases.

The original 60 GB payload was not uploaded. Its standalone FreeARC validity remains unverified; the guard does not promise extraction of proprietary installer payloads. Keep the original source file and companion installer unchanged until this is checked.
