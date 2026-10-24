# Reproducible TrID definitions

Release builds retain the 12 October 2026 snapshot with 22,456 definitions.
The original upstream `https://mark0.net/download/triddefs.zip` is a rolling
download, so its checksum changed and blocked PR #16 packaging. Updating the
hash on every build would silently change the intended detection baseline.

`scripts/refresh-helpers.ps1` now recovers the same definitions from the
published `wefalltomorrow/UniExtract2` v3.1.6 ZIP. It verifies the container
before extraction, the definitions before copying, and the definition count
with the packaged TrID executable. There is no unchecked rolling fallback.

| Item | SHA-256 |
| --- | --- |
| Original upstream ZIP (historical CI record) | `c49638a68a8091e7f05807c0ed166c9101808a861bcf12593aef6f8454d8b668` |
| v3.1.6 release ZIP | `3c66a8a976daea9f624c0b3fbb28e188a5326b1b3d9b80062a46d8d1c939171b` |
| `bin/triddefs.trd` (9,819,488 bytes) | `25af67fd79238f715e149e57491efd2c18ff5d62ca33ae1f8845a5342352b727` |

On 23 October 2026 the recovered release ZIP passed a full ZIP CRC check,
matched the published release digest, and its definitions loaded successfully
with 22,456 entries. This preserves the tested payload; it does not establish
that the newer upstream download is unsafe. GitHub release assets can be
replaced, so the digest is essential even with the versioned URL. Keep the
v3.1.6 asset available for historical builds. Only the definitions are copied
from this snapshot; no old program executables replace the current build.

TrID and TrIDLib are by Marco Pontello: <https://mark0.net/soft-trid-e.html>.
The existing `docs/third-party/TrIDLib-License.txt` permits inclusion of a
definitions package and requires retained names and attribution. Its free
edition is for noncommercial, personal, research and educational use;
commercial use requires an agreement with the author. Both that licence and
`docs/third-party/trid_readme.txt` remain in the package.

For a future update, obtain the upstream archive, record its checksum and
origin, inspect its contents, verify the count using TrID, and run the complete
packaged detection tests. Preserve the reviewed bytes in an available
versioned artifact and pin both archive and payload hashes before changing
the build. Do not just accept the next hash reported by a failed download.
