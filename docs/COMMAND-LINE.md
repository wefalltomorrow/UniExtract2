# Command-line reference

Universal Extractor accepts a file path as its first normal argument. With no arguments it opens the graphical interface.

## Syntax

```text
UniExtract.exe <file> [<destination> | /scan | /sub | /last] [/silent] [/batch] [/type[=<type>]]
```

## Extraction arguments

| Argument | Meaning |
| --- | --- |
| `<file>` | File to inspect or extract. |
| `<destination>` | Explicit output directory. |
| `/sub` | Extract to a subdirectory named after the input file. |
| `/last` | Use the last output directory. |
| `/scan` | Detect/report the file type without extracting. |
| `/type=<type>` | Force an extraction type. |
| `/type` | Open the extraction-type selection dialog. |
| `/silent` | Suppress prompts and interactive first-run UI where possible. |
| `/batch` | Add the file to the batch queue instead of extracting it immediately. |

`/type=<type>` is parsed after the destination/scan argument, so a typical forced extraction command is:

```text
UniExtract.exe "C:\Files\sample.bin" /sub /type=7z
```

## Other switches

| Switch | Meaning |
| --- | --- |
| `/help`, `/?`, `/h`, `-h`, `-?`, `--help` | Show command-line help. |
| `/update` | Check for updates. |
| `/updatehelper`, `/updatehelpers` | Update helper files. |
| `/plugins` | Open plugin management. |
| `/uninstall` | Open uninstall/cleanup handling. |
| `/removeuserdata` | With silent uninstall, also remove user data. |
| `/batchclear` | Clear the batch queue. |
| `/nolog` | Disable log creation for the current run. |
| `/nostats` | Disable statistics for the current run. Statistics/feedback endpoints are already disabled in this fork. |
| `/close` | Exit after command-line processing. |
| `/afterupdate` | Internal post-update entry point used by the updater. |

## Examples

Extract to an explicit directory:

```text
UniExtract.exe "C:\Downloads\setup.exe" "C:\Temp\setup"
```

Extract next to the input file in its own subdirectory without prompts:

```text
UniExtract.exe "C:\Downloads\archive.zip" /sub /silent
```

Scan only:

```text
UniExtract.exe "C:\Downloads\unknown.bin" /scan
```

Queue an item for batch extraction:

```text
UniExtract.exe "C:\Downloads\archive.7z" /sub /batch
```

Force the 7-Zip extraction path:

```text
UniExtract.exe "C:\Downloads\odd-file.bin" /sub /type=7z
```

Force the optional Game Extractor fallback (requires Game Extractor Basic installed through the Plugin Manager):

```text
UniExtract.exe "C:\Games\unknown.pak" /sub /type=gameextractor
```

Force the optional vgmstream game-audio decoder:

```text
UniExtract.exe "C:\Games\audio\voice.wem" /sub /type=vgmstream
```

## Exit behavior

UniExtract uses different internal status/exit values for success, unsupported files, invalid paths, extraction failures and silent/internal termination. When automating it, test the exit code and the generated log rather than assuming that every non-interactive run produced output.
