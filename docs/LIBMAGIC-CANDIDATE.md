# file/libmagic 5.48 Windows candidate

PR #13 remains a separate draft. It is not part of the FreeArc v3.1.7 candidate.
The x64 file.exe/magic.mgc pair is preferred on 64-bit Windows; the existing
x86 pair remains available for 32-bit Windows and unsuccessful x64 detection.

## Corrections and validation (October 24, 2026 UTC)

- Normalize detector output before deciding whether to retry the legacy tool.
  The old check missed filename-prefixed "data" output. Tool errors, missing
  databases and launch failures are now rejected as identifications. Brief
  output avoids depending on filename rendering in the helper's code page.
- Removed the duplicate helper-refresh invocation during packaging.
- Replaced rolling MSYS2 installation with five exact official package
  downloads. Each package is SHA-256 checked before extraction; all seven
  existing runtime/database hashes are retained and checked before execution.
  The matching dependency license notices and package inventory are included.
- Include the five matching official source packages, patches and build
  recipes alongside the license notices. Their checksums are pinned, and
  every recipe checksum must match the corresponding binary `.BUILDINFO`.
  See [source and rebuild information](LIBMAGIC-SOURCES.md).
- Local Windows PowerShell 5.1 checks verify DLL import closure, isolated
  version/text/PE/ZIP recognition, and the production AutoIt fallback path.
  The new fallback regression fails against the original implementation.
- Isolated Windows CI run 40099053972 passed at commit 0442f6b. A local
  application overlay also passed ZIP, Unicode ZIP, ADX, ACE (247 files),
  malformed FreeArc routing and packaged libmagic checks. This overlay uses
  the earlier verified helper package and is not a release artifact.

The supplied MSYS2 build and the existing legacy helper both failed a Japanese
input path on the validation machine's active code page, returning "cannot
open" with exit code zero. This is a known helper limitation, not successful
Unicode recognition. The application rejects that diagnostic and retains
other detection routes. The isolated test records this limitation explicitly;
The local application overlay passed Unicode ZIP extraction through the
remaining detection routes; the final CI package must pass the same check.

## Reproducible input packages

Official downloads use https://mirror.msys2.org/mingw/mingw64/ and the filename
prefix mingw-w64-x86_64- with suffix -any.pkg.tar.zst. No Pacman installation
or global MSYS2 runtime is needed. scripts/get-libmagic-548.ps1 records the full
URLs and pinned SHA-256 values in the shipped PACKAGES.csv.

| Package/version | SHA-256 |
| --- | --- |
| file-5.48-1 | 844a8e6451f51aa9bfcbbdf92248b0e406891a51738ad2d8161835d7100d4f3f |
| gettext-runtime-1.0-1 | be68d7f260633284b910c588c6d82ee304a81c8817a686d2cd9df83f872c27af |
| libiconv-1.19-1 | 21e334d0911f25de75d3e18e0697648bcecfa9658256d600cad0827d719c2f35 |
| libsystre-1.0.2-3 | ea20a54127fe2a606ef0f2bef62b1abef77710840b661b832a933b4020bfe316 |
| libtre-0.9.0-2 | c4051508d063258e1e02dd29615edb7d73c5c5f582ae42795fdd92e7ddce506b |

The dependency versions were recovered from the earlier successful candidate
workflow 38238569207. Newly downloaded official packages reproduce every
previously recorded binary/database hash. These are deliberate pins, not
claims that these package versions are the newest available.

| Runtime file | SHA-256 |
| --- | --- |
| file.exe | 0d7d9d14f2cbbf3e941219ec819cd450a851d06ab9104ef20f7b0f22b7f97f84 |
| libmagic-1.dll | 73e9ab47916462ca1631cf165385eeb8664333cf7740c54ed6f9e2e2d8f6c798 |
| libsystre-0.dll | 4bc4dae17267afec9f9812e88167980808848c10a255ccbda9ef4fd758897938 |
| libtre-5.dll | 5833b2b1f62b67d8b4b3881f1bc05f42b0dee1a9f10cef897cdf44d74d094fdf |
| libintl-8.dll | 0537c3dd2378218508ebe3cc416d72a99ee2d24ae1c5525e23458f32544ef861 |
| libiconv-2.dll | 7a282a854e01be726c6cccfe46f548c716aa45b3014818468253aaa4efbcd067 |
| magic.mgc | 1a98967ddb2a9ef80f9dd1a3f1fa3bebc4991741878a512310f0d434428de85e |

## Remaining release gates

Update the branch with the stable FreeArc changes after their independent
validation; resolve conflicts without losing either suite. Run the complete
Windows build and packaged tests, verify downloaded artifacts and detector
behavior, and complete the redistribution audit before marking PR #13 ready.
