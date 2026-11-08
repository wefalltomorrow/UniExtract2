# Bio.cs 2.6.0 compatibility candidate

This is an isolated test build, NOT an update to the current release. The bundled Bio.cs.dll is 2.5.0.

Upstream Bio.cs 2.6.0 changed FileOpen(string, FileMode) and Read8BitPrefixedString(BinaryReader, bool) by adding optional parameters. Optional C# arguments do not preserve the old CLR signatures. Existing compiled extractors may otherwise throw MissingMethodException.

The build downloads immutable upstream commit 716ebe500a4b69839bd5383baa97d57ba7f21335, restores those old overloads, builds net40 and verifies all four method signatures in the output assembly. The candidate DLL and license are uploaded only as a separate CI artifact.

The compatibility patch also preserves the public BioLib.CLI.DefaultOptions
type, its parameterless constructor and writable Boolean help field. The field
retains the original internal OptionAttribute metadata (Name = h, Description =
Show help message). The builder checks those values and the field's initial
false value and write behavior. The framework check rejects a target other than
.NET Framework 4.0, matching the shipped 2.5 DLL. These checks run on the host's
installed Framework; they do not establish behavior on a machine with only 4.0.

tests/biolib-legacy-client.ps1 accepts BaselineDll and CandidateDll paths. It
checks the baseline's pinned SHA-256, compiles a small client against that actual
2.5 DLL and runs the identical executable in separate baseline/candidate
directories. It checks the restored type and metadata plus both old method
entrypoints. Running it against the earlier unpatched 2.6 candidate must fail.
This focused binary-compatibility test does not replace extraction fixtures.

The six-client known-output suite is documented in [BIOLIB-FIXTURES.md](BIOLIB-FIXTURES.md).
It compares pinned published clients with both libraries and reproduces an
existing Godot payload-position bug. A separately built Godot repair passes the
correctness tests with both libraries. Packaging and broader API/format coverage
remain promotion gates; these finite fixtures do not prove full compatibility.

Upstream: https://github.com/Bioruebe/Bio.cs/releases/tag/2.6.0
