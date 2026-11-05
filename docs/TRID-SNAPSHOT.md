# Reproducible TrID definitions

Release builds now retain the gvp9000 v3.0.12 snapshot with 22,576 definitions.
The SHA-pinned helper base already contains this payload; the maintained overlay
verifies it instead of downloading and restoring the older v3.1.6 snapshot.

| Current item | SHA-256 |
| --- | --- |
| gvp9000 v3.0.12 ZIP | b37dd77c7b8ace7197655f04f50ef7049b54b311c37906c94cc65542d829f26b |
| bin/triddefs.trd (9,876,520 bytes) | a092677e8ba257d2ea8942dfefdd25a89c4b748258c0b828ef17a0bd463edce7 |

The snapshot loads 22,576 definitions with packaged TrID 2.48. A stale cache is
removed before validation. The exact originating definition publication date is
not inferred from the package timestamp.

## Historical snapshot used through v3.1.9

Earlier release builds retained the 12 October 2026 snapshot with 22,456 definitions.
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
