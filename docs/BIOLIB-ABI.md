# Bio.cs 2.6.0 compatibility candidate

This is an isolated test build, NOT an update to the current release. The bundled Bio.cs.dll is 2.5.0.

Upstream Bio.cs 2.6.0 changed FileOpen(string, FileMode) and Read8BitPrefixedString(BinaryReader, bool) by adding optional parameters. Optional C# arguments do not preserve the old CLR signatures. Existing compiled extractors may otherwise throw MissingMethodException.

The build downloads immutable upstream commit 716ebe500a4b69839bd5383baa97d57ba7f21335, restores those old overloads, builds net45 and verifies all four method signatures in the output assembly. The candidate DLL and license are uploaded only as a separate CI artifact.

To ship this later, run real extraction regression samples through the exact bundled Bioruebe utilities (cicdec, godotdec, rmvdec, sgbdec, simdec, spoondec and related tools). Reflection tests alone are not sufficient.

Upstream: https://github.com/Bioruebe/Bio.cs/releases/tag/2.6.0