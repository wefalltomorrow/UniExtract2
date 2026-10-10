# vgmstream game-audio fallback

The upcoming UniExtract update includes **vgmstream r2117**, an upstream tagged (non-nightly) build, packaged separately for x86 and x64 Windows. The helper overlay verifies both downloaded ZIP files against SHA-256 digests published in upstream GitHub release metadata and keeps the adjacent codec DLLs with the CLI executable.

The program looks for `bin\x86\vgmstream\vgmstream-cli.exe` or `bin\x64\vgmstream\vgmstream-cli.exe` according to the Windows architecture. The existing Windows AutoIt application remains x86; the decoder helper can run as x64 when appropriate.

## When UniExtract tries it

All existing dedicated format handlers, GARbro, QuickBMS, extension handlers, generic 7-Zip and the optional Game Extractor archive fallback retain priority. vgmstream is only attempted on the following extensions if those handlers did not succeed:

`.adx`, `.hca`, `.brstm`, `.bfstm`, `.bcstm`, `.bwav`, `.dsp`, `.wem`, `.xwb`, `.xma`, `.fsb`, `.bnk`, `.awb`, `.nus3audio`, `.at3`, `.at9`, `.genh`.

It invokes the upstream decoder with `-i` (ignore playback loops) and exports a WAV through a temporary directory. Only a nonempty WAV is accepted as successful. Failed decodes leave the existing unknown-format path intact, without replacing FFmpeg or the primary archive handlers.

This initial integration extracts the **first/default audio stream only**. Audio-bank files can contain many subsongs: automatic all-subsong expansion is deferred pending capped-output and fixture tests. Decoding is not the same as unpacking every file from an archive.

## Validation needed before release

- Windows x86 and x64 helper download, hash and CLI-loading checks run in `scripts/refresh-helpers.ps1`.
- Run the normal CI compile, package and ZIP smoke tests.
- Test at least one known game-audio sample (for example ADX or HCA), an unsupported sample, and a multi-subsong bank before declaring broader format coverage.
- Verify the fallback does not alter generic WAV/MP3/ZIP extraction.

Project: https://github.com/vgmstream/vgmstream

Release: https://github.com/vgmstream/vgmstream/releases/tag/r2117
