#!/usr/bin/env python3
"""Stage the closed DLL dependency tree of a Windows PE from a supplied prefix.

No implicit MSYS2 PATH is allowed in the final test: every non-OS DLL must be
present beside file.exe in the isolated candidate directory.
"""
import os
import pathlib
import shutil
import sys
import pefile

if len(sys.argv) != 4:
    raise SystemExit("usage: stage-pe-deps.py <mingw64-bin> <candidate-dir> <file.exe>")
source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
seed = pathlib.Path(sys.argv[3])
destination.mkdir(parents=True, exist_ok=True)
pending = [seed]
seen = set()
windows = pathlib.Path(os.environ.get("WINDIR", r"C:\Windows"))
system32 = windows / "System32"
forbidden = {"msys-2.0.dll"}   # would make the result an MSYS-only executable
while pending:
    path = pending.pop()
    name = path.name.lower()
    if name in seen:
        continue
    seen.add(name)
    if not path.is_file():
        raise SystemExit("Missing DLL or executable: " + str(path))
    target = destination / path.name
    shutil.copy2(path, target)
    print("Stage:", path.name, path.stat().st_size)
    pe = pefile.PE(str(path), fast_load=True)
    pe.parse_data_directories(directories=[
        pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IMPORT"],
        pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT"],
    ])
    try:
        imports = list(getattr(pe, "DIRECTORY_ENTRY_IMPORT", [])) + list(
            getattr(pe, "DIRECTORY_ENTRY_DELAY_IMPORT", []))
        for imp in imports:
            dll = imp.dll.decode("ascii", "replace").lower()
            if dll in forbidden:
                raise SystemExit("Unexpected MSYS runtime dependency: " + dll)
            if dll in seen or dll.startswith(("api-ms-win-", "ext-ms-win-")):
                continue
            match = source / dll
            if match.is_file():
                pending.append(match)
            elif not (system32 / dll).is_file():
                raise SystemExit(f"Unresolved runtime import: {path.name} -> {dll}")
    finally:
        pe.close()
print("Closed PE dependency tree:", len(seen), "files")
