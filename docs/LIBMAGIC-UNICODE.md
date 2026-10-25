# Unicode paths for file/libmagic

The bundled x86 and x64 file.exe helpers can reject filenames outside the
active Windows ANSI code page. Passing a quoted Unicode path to their command
line does not solve that conversion. The same applies to an absolute magic.mgc
argument when Universal Extractor is installed in a Unicode directory.

The detector now starts cmd.exe with AutoRun and delayed expansion disabled.
Windows opens the input through redirection and passes the resulting regular
file handle as standard input. file.exe receives -b -m magic.mgc - with its
own directory as the working directory. The input remains seekable; no stream
pipe, whole-file copy, rename, hard link or 8.3 filename is required.

Executable and input paths are expanded once from process-specific environment
variables inside quotes. Literal percent signs, exclamation marks, ampersands,
carets and parentheses remain path characters. The previous environment values
are restored after each call. A completion marker emitted only on command
success prevents localized redirection/launch errors and partial timeout output
from being accepted as file types. Existing unknown/error filtering and legacy
fallback remain in place.

tests/libmagic-unicode.ps1 executes the production detector and process runner
against the packaged helpers. Both the input folder and copied helper/database
folder contain Japanese characters and shell metacharacters. It checks ZIP,
text, PE and PDF recognition, unknown input, missing input, missing executable,
missing database, environment restoration and unchanged input hashes, sizes,
modification times and directory contents. On x64 Windows it exercises both
the x86 legacy helper and x64 5.48 bundle. -SourceFile can point to v3.1.8
source to demonstrate the prior failure. Mocked fallback tests separately
cover launch failure, incomplete output, x86 selection and absent x64 bundles.

This change concerns file/libmagic detection. It does not establish Unicode
support for every extraction helper or change the application's existing
Unicode handling for those helpers.
