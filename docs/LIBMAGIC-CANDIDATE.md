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
