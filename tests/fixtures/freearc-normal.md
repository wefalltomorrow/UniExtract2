# Normal FreeArc regression fixture

freearc-normal.arc contains one hello.txt with exactly 32 ASCII bytes:
Universal Extractor 2 smoke test

Generated locally from that synthetic text with FreeArc 0.67 (March 15 2014),
from the checksum-verified PeaZip 11.3.0 package used by refresh-helpers.ps1.
Command: Arc.exe a -m0 -ep normal.arc hello.txt
No game content or user-supplied opaque unpacker was used.

SHA-256: 8ad0947c56489f6a67fa16df743bd537b92f2c61792a1fd81efa5e14efba97b4

The packaged application must extract the exact text with the optional
external backend disabled. The stored method keeps this fixture small and
tests native FreeArc routing and decoding, not custom codec compatibility.
