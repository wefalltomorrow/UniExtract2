# vgmstream integration

Universal Extractor can use **vgmstream** as an optional fallback for streamed video-game audio.

## Why it is separate from Game Extractor

The Game Extractor package includes a vgmstream executable, but the copy examined in the supplied Full package identifies itself as `r1917-39-g46eb81ac (May 12 2024)`. vgmstream is still actively developed, so UniExtract should use the current upstream package instead of inheriting an old copy from another application.

The official rolling Windows builds are published at:

```text
https://github.com/vgmstream/vgmstream-releases/releases/latest
```

## Installation

Install the appropriate Windows package through UniExtract's Plugin Manager, or extract the official `vgmstream-win*.zip` package into:

```text
bin\vgmstream\
```

UniExtract expects:

```text
bin\vgmstream\vgmstream-cli.exe
```

Keep the DLLs distributed alongside the CLI in the same directory.

## Routing

vgmstream is intentionally a low-priority fallback.

UniExtract first tries its normal file-specific handlers, game/archive extractors, extension routes, 7-Zip and the optional Game Extractor backend. Only if those do not handle the input does UniExtract probe vgmstream.

The probe is metadata-only:

```text
vgmstream-cli.exe -m -I "<input>"
```

Current vgmstream emits JSON metadata for accepted files. UniExtract requires the expected `sampleRate`, `channels` and `streamInfo` fields before starting a decode, instead of guessing from extensions such as `.bin`, `.dat`, `.wav` or other names that can mean many unrelated formats.

## Extraction behavior

Accepted inputs are decoded with:

```text
vgmstream-cli.exe -i -S 0 -o "<output>\<name>_?04s.wav" "<input>"
```

- `-i` ignores loop repetition and decodes each stream once.
- `-S 0` requests every subsong/stream in a bank.
- `?04s` gives multi-stream output deterministic numbered names.
- The extraction is accepted only when real output was created and the CLI did not report a fatal open/time-configuration failure.

This is deliberately different from simply handing every unknown file to an audio decoder.

## Scope

vgmstream decodes streamed game audio to WAV. It is not an archive extractor and it does not encode WAV files back into game formats.

Its useful coverage includes many engine/platform-specific formats and codecs that FFmpeg alone does not understand, along with companion-file and multi-subsong cases.

## Licensing

The vgmstream project uses an ISC-style licence. Its prebuilt Windows package also includes optional codec libraries and other dependencies with their own licences, including FFmpeg components.

For that reason vgmstream remains an optional externally sourced plugin rather than being copied from the paid Game Extractor package or silently folded into UniExtract's normal helper bundle.
