# file/libmagic 5.48 Windows candidate

This is a **standalone validation experiment**, not a replacement for the current `bin/file.exe` and `bin/magic.mgc`. The bundled 32-bit legacy helper stays untouched.

Upstream MSYS2 `mingw-w64-x86_64-file` version 5.48-1 publishes:
- `file.exe`
- `libmagic-1.dll`
- the matching compiled `magic.mgc` database
- the file/libmagic redistribution license

Official package checksum (SHA-256): `844a8e6451f51aa9bfcbbdf92248b0e406891a51738ad2d8161835d7100d4f3f`.

The upstream package depends on `libsystre`, which itself depends on `libtre` and further runtime libraries. The Windows workflow installs the upstream package under MSYS2, downloads and validates the pinned archive digest, recursively copies its non-OS PE dependencies into a clean staging directory, and runs `file --version` plus PE, text and ZIP recognition **without MSYS2 on PATH**. A checksum manifest and candidate ZIP are uploaded only as CI artifacts.

**Next requirements before integrating:** investigate x86 5.48 builds or retain x86 5.46; choose an isolated x64 fallback and update AutoIt's `file.exe -m magic.mgc` invocation only with platform checking; compare detection behavior and downstream extractor selection for representative archives; confirm the licensing and all transitive DLL hashes are pinned in the production packaging script.

The current published release remains untouched by this test.

## Verified Windows candidate (CI passed)

Run: https://github.com/wefalltomorrow/UniExtract2/actions/runs/38019487289

Official 5.48-1 MSYS2 package SHA-256 matched the pinned checksum, the isolated import closure contained six binaries, and PE32+, ASCII text, and ZIP identification succeeded without MSYS2 on PATH. The matching `magic.mgc` was copied and used in every scan.

| Runtime file | SHA-256 |
|---|---|
| `file.exe` | `0d7d9d14f2cbbf3e941219ec819cd450a851d06ab9104ef20f7b0f22b7f97f84` |
| `libmagic-1.dll` | `73e9ab47916462ca1631cf165385eeb8664333cf7740c54ed6f9e2e2d8f6c798` |
| `libsystre-0.dll` | `4bc4dae17267afec9f9812e88167980808848c10a255ccbda9ef4fd758897938` |
| `libtre-5.dll` | `5833b2b1f62b67d8b4b3881f1bc05f42b0dee1a9f10cef897cdf44d74d094fdf` |
| `libintl-8.dll` | `0537c3dd2378218508ebe3cc416d72a99ee2d24ae1c5525e23458f32544ef861` |
| `libiconv-2.dll` | `7a282a854e01be726c6cccfe46f548c716aa45b3014818468253aaa4efbcd067` |
| `magic.mgc` | `1a98967ddb2a9ef80f9dd1a3f1fa3bebc4991741878a512310f0d434428de85e` |

These are **candidate audit values**, not evidence of full UniExtract integration. All original x86 files are still untouched, and no 5.48 file/libmagic binary has been added to the published release package.
