#!/usr/bin/env python3
"""Offline, no-flash builder of the Stage7R minimal newc+gzip Magisk ramdisk.

Inputs must come from a user-owned Magisk 30.7 installation/patch of the SAME
watch. Does not create/modify a boot image, AVB signature or private key.
"""
import argparse
import gzip
import hashlib
from pathlib import Path

DIRS = [
    ("dev", 0o040755), ("proc", 0o040755), ("sys", 0o040755),
    ("data", 0o040755), (".backup", 0o040000),
    ("overlay.d", 0o040750), ("overlay.d/sbin", 0o040750),
]


def newc(entries):
    result = bytearray()
    for index, (name, mode, data) in enumerate(entries + [("TRAILER!!!", 0, b"")], 1):
        name_bytes = name.encode("ascii") + b"\x00"
        fields = [index, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0,
                  len(name_bytes), 0]
        result.extend(b"070701")
        result.extend(b"".join(f"{field:08x}".encode("ascii") for field in fields))
        result.extend(name_bytes)
        result.extend(b"\x00" * (-len(result) % 4))
        result.extend(data)
        result.extend(b"\x00" * (-len(result) % 4))
    return bytes(result)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--magiskinit", required=True, type=Path)
    p.add_argument("--magisk-xz", required=True, type=Path)
    p.add_argument("--stub-xz", required=True, type=Path)
    p.add_argument("--init-ld-xz", required=True, type=Path)
    p.add_argument("--config", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    a = p.parse_args()
    config = a.config.read_bytes()
    if b"RECOVERYMODE=true\n" not in config or b"PREINITDEVICE=" not in config:
        p.error("Missing RECOVERYMODE=true or PREINITDEVICE in config; do not guess")
    init = a.magiskinit.read_bytes()
    if not init.startswith(b"\x7fELF"):
        p.error("magiskinit is not an ELF executable")
    files = [
        ("init", 0o100750, init),
        (".backup/.magisk", 0o100000, config),
        ("overlay.d/sbin/magisk.xz", 0o100644, a.magisk_xz.read_bytes()),
        ("overlay.d/sbin/stub.xz", 0o100644, a.stub_xz.read_bytes()),
        ("overlay.d/sbin/init-ld.xz", 0o100644, a.init_ld_xz.read_bytes()),
    ]
    if any(not data for _, _, data in files):
        p.error("One or more Magisk inputs are empty")
    entries = [(name, mode, b"") for name, mode in DIRS] + files
    raw = newc(entries)
    output = gzip.compress(raw, compresslevel=9, mtime=0)
    if len(output) > 500_000:
        p.error(f"Output unexpectedly large: {len(output)} bytes; investigate before signing")
    if a.output.exists():
        p.error(f"Refusing to overwrite: {a.output}")
    a.output.write_bytes(output)
    print(f"Wrote {a.output} ({len(output)} bytes, {len(raw)} bytes uncompressed)")
    print("SHA256:", hashlib.sha256(output).hexdigest())
    print("OFFLINE RAMDISK ONLY — NOT A FLASHABLE BOOT IMAGE. NO SIGNING PERFORMED.")


if __name__ == "__main__":
    main()
