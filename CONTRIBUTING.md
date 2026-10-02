# Contributing

Contributions are welcome, especially fixes that come with a reproducible sample or clear test case.

## Before opening a pull request

- Keep the change focused.
- Test the affected format on Windows.
- Do not add third-party binaries directly to the source tree.
- If a new extractor/helper is required, document its source, version and license in `docs/helper_binaries_info.txt`.
- Preserve existing credits and third-party licensing.
- Avoid unrelated formatting churn in the large AutoIt source file.

## Building

Install AutoIt 3.3.18.0 and SciTE4AutoIt3, then run:

```powershell
.\scripts\build.ps1
```

A pull request should compile all three executables before it is merged.

## Extraction fixes

For format/extractor bugs, include:

- a public/legal sample when possible
- the previous behavior
- the expected behavior
- the UniExtract log
- the exact helper/extractor involved if known

If a sample cannot be shared publicly, describe the file format and failure as precisely as possible.
