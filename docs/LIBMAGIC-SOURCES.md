# Sources and notices for the libmagic 5.48 runtime

The x64 runtime in `bin/x64/libmagic548` uses the unmodified binaries from
the exact MSYS2 packages listed in `docs/third-party/libmagic548/PACKAGES.csv`.
The bundled license and copyright notices are under that directory
in `licenses/`. They cover file/libmagic, libsystre, TRE, GNU gettext
libintl and GNU libiconv. Only the selected runtime DLLs and file.exe are
installed; unrelated command-line programs from the packages are not shipped.

The complete official source packages are included alongside the notices in
`sources/`, including upstream source, MSYS2 patches and build recipes.
`SOURCES.csv` records their original URLs and SHA-256 values. Packaging
verifies that each PKGBUILD matches the checksum recorded in the corresponding
binary package's `.BUILDINFO`, which is also included. No source or build
script is executed during this verification.

To inspect or rebuild a component, unpack its `.src.tar.zst` with 7-Zip
(first the Zstandard layer, then the TAR). Use the included PKGBUILD in an
MSYS2 MINGW64 build environment with its declared build dependencies. The
recorded `.BUILDINFO` lists the original build environment. TRE's source
package contains a Git object database for the pinned upstream tag; the other
packages contain source archives or source files directly. Follow the
included upstream build instructions and MSYS2 recipe for that component.

The dynamically loaded DLLs are ordinary replaceable files beside file.exe.
Users may rebuild and replace compatible versions, subject to each
component's license. UniExtract invokes file.exe as a separate helper.
The source archives are included so recipients do not have to depend on
continued availability of an external download to obtain these sources.
