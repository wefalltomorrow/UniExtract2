# Optional external FreeArc compatibility backend

## Why this exists

Some proprietary installer payloads start with the standard FreeArc ArC\x01
header but require a custom FreeArc decompressor. The stock FreeArc 0.666
unarc.exe packaged with UniExtract2 can reject these with
"descriptor failed CRC check" although the payload is readable with the
original installer's FreeArcExtract-compatible DLL and wrapper.

An actual user-supplied, 59.9 GB setup-1.bin (Forza Horizon 3 RUNE release)
was confirmed to extract using an external CODEX-style wrapper, while both
Universal Extractor 2.0 RC3 and our v3.1.6 reported a stock unarc failure.
This is a user-reported result with the standalone wrapper. The integrated
fallback has not yet been verified against that archive, and the roles of
password, codec support and decoder modifications remain unresolved.

## Opt-in use

This feature is **disabled by default**. We neither bundle the
user-supplied unpacker nor automatically search for executable files.

1. Obtain an external FreeArc-compatible unpacker from a source you trust,
   inspect it, and keep its original unpack.exe, unarc.dll, config.ini,
   and arc.ini in one private folder. These files are not supplied with UniExtract.
2. Ensure its own config.ini contains any required Password= entry or other
   tool-specific settings. Do not send passwords to a diagnostic log.
3. Add this section to the UniExtract.ini being used by your UniExtract2:

   [FreeArc]
   ExternalUnpackerEnabled=1
   ExternalUnpackerDir=C:\Tools\CustomFreeArc
   ExternalUnpackerTimeoutSeconds=21600

4. Extract the FreeArc input normally. UniExtract first tries its bundled
   standard unarc.exe. If the standard decoder fails, the opt-in compatibility
   backend stages the four user-provided files into a separate temporary
   directory beside the destination, updates InputFile, OutputPath, WorkPath
   and CfgFile in the staged config.ini, and launches unpack.exe there with
   config.ini as its only argument. The destination must be new or empty.
   The flat config must contain exactly one of each of those four keys;
   duplicate keys and INI sections are rejected. The original text encoding
   is retained and the staged text is checked for encoding loss.

   The original external unpacker folder and its config are never modified.
   The supplied password is retained only in the temporary config, not passed
   as a command-line argument and not added to UniExtract diagnostic reports.
   Both process output streams are discarded to avoid wrapper-generated
   password leaks. The temporary working directory is deleted on completion
   or orderly application exit, if possible. Timeout defaults to six hours;
   accepted settings are 1 to 86400 seconds. Tray cancellation also stops
   the attempt. A Windows kill-on-close job handles attached child processes.

5. Disable the integration again by setting ExternalUnpackerEnabled=0.

## Safety and limitations

- **Unknown executables are risky.** Enable only for an external unpacker you
  deliberately trust. UniExtract does not vet, verify, redistribute or license
  scene-supplied binaries. Antivirus and digital-signature checks are sensible.
- The opt-in backend is not a guaranteed decoder: other releases may use
  different FreeArc formats, compression methods, encryption or auxiliary DLLs.
  It expects the four files and config syntax shown above.
- Output is written to a separate staging directory on the destination volume.
  Success requires exit code zero, at least one staged file, no detected
  reparse points, and a successful directory rename into a still-empty or
  absent destination. Existing files are never merged or replaced by the
  commit step. Failed attempts discard staged output. A file count is only
  an output-presence check: it cannot prove archive completeness or content
  integrity without a trusted reference manifest.
- Staging and process jobs are not a security sandbox. A trusted wrapper must
  honor the supplied paths, finish extraction before it exits, and support
  the config's encoding. Arbitrary executable code can access other paths or
  escape normal process lifetime assumptions. Additional codecs/DLLs beyond
  the four required files are not copied automatically.
- The current fallback is not automatically tested with the original 60 GB
  archive in public CI. The runtime tests compile a harmless source-controlled
  wrapper and exercise Unicode/spaces, UTF-8 and UTF-16 configs, unchanged
  source settings, output content, nonzero/empty results, destination races,
  cancellation, timeout, child cleanup, reparse rejection and credential
  suppression. No uploaded opaque binaries are run by these tests.
- Credentials in a temporary config are sensitive even if not logged. Work on
  a trusted machine; cleanup is best effort. Power loss, forced termination
  or locked files can leave a sibling .UniExtract2-FreeArc-* directory with
  sensitive config or partial output. Remove such remnants after ensuring
  the associated processes have stopped.
- No attempt is made to replace the built-in backend with generic arc.exe,
  which is not necessarily compatible with custom-coded installer archives.

## Report correctness

On a failed standard unarc.exe attempt, UniExtract reports the attempted
extractor rather than calling it "7z". The HTML badge derives from the **final
status**, not from the mere presence of WARN steps, so NOTSUPPORTED will no
longer show "SUCCESS WITH WARNINGS". A successful opt-in run records the
external unpacker as the winner.

The stock decoder's "descriptor failed CRC check" message is classified as
a failed tool attempt. This does not prove that the source file is damaged;
codec and password incompatibilities can produce superficially similar errors.
