#!/usr/bin/env python3
"""Checks a Readle release bundle before it goes to Play. Used by tool/release.sh.

  check_release.py <app.aab> <merged AndroidManifest.xml> <version> <release-notes.md>
  check_release.py --self-test

Fails (exit 1) when:
- the bundle is debug-signed or unsigned (Play rejects it; the upload key must sign it);
- the AdMob app id is Google's sample id, or not Readle's (test ads in production);
- the build is debuggable, or targets an API level Play no longer accepts;
- a native library isn't aligned for 16 KB memory pages (Play requires it for Android 15+);
- the engine and app libraries weren't stripped (their symbols belong in BUNDLE-METADATA, the
  same test Flutter runs with apkanalyzer), or the R8 mapping is missing (Play deobfuscates
  Java/Kotlin crashes with it);
- the release notes have no entry for this version, or an entry over Play's 500 characters.
"""
import re
import struct
import subprocess
import sys
import tempfile
import zipfile

READLE_ADMOB_APP = "ca-app-pub-5964569110696877~7982698610"
SAMPLE_ADMOB_APP = "ca-app-pub-3940256099942544~3347511713"
MIN_TARGET_SDK = 35  # Play: new apps and updates target Android 15+ (from 31 Aug 2025)
PAGE_16K = 0x4000
NOTES_MAX = 500  # Play "What's new", per language


def elf_load_alignments(data: bytes) -> list[int]:
    """p_align of every PT_LOAD segment of a 32- or 64-bit little-endian ELF file."""
    if data[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    is64 = data[4] == 2
    if is64:
        phoff, = struct.unpack_from("<Q", data, 0x20)
        phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    else:
        phoff, = struct.unpack_from("<I", data, 0x1C)
        phentsize, phnum = struct.unpack_from("<HH", data, 0x2A)
    aligns = []
    for i in range(phnum):
        off = phoff + i * phentsize
        p_type, = struct.unpack_from("<I", data, off)
        if p_type != 1:  # PT_LOAD
            continue
        aligns.append(struct.unpack_from("<Q", data, off + 0x30)[0] if is64 else struct.unpack_from("<I", data, off + 0x1C)[0])
    return aligns


def misaligned_libs(aab: str) -> list[str]:
    bad = []
    with zipfile.ZipFile(aab) as z:
        for name in z.namelist():
            if name.endswith(".so") and "/lib/" in "/" + name:
                aligns = elf_load_alignments(z.read(name))
                if not aligns or min(aligns) < PAGE_16K:
                    bad.append(f"{name} (LOAD align {hex(min(aligns)) if aligns else 'none'})")
    return bad


def missing_metadata(aab: str) -> list[str]:
    with zipfile.ZipFile(aab) as z:
        names = z.namelist()
    meta = "BUNDLE-METADATA/com.android.tools.build."
    missing = [
        f"{lib} symbols in {meta}debugsymbols (the .so files were not stripped)"
        for lib in ("libflutter.so", "libapp.so")
        if not any(n.startswith(meta + "debugsymbols/") and n.endswith((f"/{lib}.sym", f"/{lib}.dbg")) for n in names)
    ]
    if meta + "obfuscation/proguard.map" not in names:
        missing.append("the R8 mapping (BUNDLE-METADATA/.../obfuscation/proguard.map)")
    return missing


def signer(aab: str) -> str:
    out = subprocess.run(["keytool", "-printcert", "-jarfile", aab], capture_output=True, text=True).stdout
    m = re.search(r"Owner: (.+)", out)
    return m.group(1).strip() if m else ""


def notes_entry(notes: str, version: str) -> str | None:
    """The text under the '## <version>' heading of the release notes, or None."""
    m = re.search(rf"^## {re.escape(version)}\s*\n(.*?)(?=^## |\Z)", notes, re.S | re.M)
    return m.group(1).strip() if m else None


def check(aab: str, manifest: str, version: str, notes_path: str) -> list[str]:
    problems = []
    owner = signer(aab)
    if not owner:
        problems.append("the bundle is not signed")
    elif "Android Debug" in owner:
        problems.append(f"debug-signed ({owner}): add the upload key (android/key.properties)")
    m = open(manifest, encoding="utf-8").read()
    if SAMPLE_ADMOB_APP in m or READLE_ADMOB_APP not in m:
        problems.append("the AdMob app id is not Readle's release id")
    if 'android:debuggable="true"' in m:
        problems.append("the manifest is debuggable")
    t = re.search(r'android:targetSdkVersion="(\d+)"', m)
    if not t or int(t.group(1)) < MIN_TARGET_SDK:
        problems.append(f"targetSdkVersion {t.group(1) if t else '?'} < {MIN_TARGET_SDK}")
    problems += [f"not 16 KB aligned: {b}" for b in misaligned_libs(aab)]
    problems += [f"missing {m}" for m in missing_metadata(aab)]
    entry = notes_entry(open(notes_path, encoding="utf-8").read(), version)
    if not entry:
        problems.append(f"no release notes for {version} in {notes_path} (a '## {version}' section)")
    elif len(entry) > NOTES_MAX:
        problems.append(f"release notes for {version} are {len(entry)} characters (Play allows {NOTES_MAX})")
    return problems


def _elf(is64: bool, aligns: list[int]) -> bytes:
    """A minimal ELF header plus program headers, enough for elf_load_alignments."""
    if is64:
        head = bytearray(0x40)
        head[:5] = b"\x7fELF\x02"
        struct.pack_into("<Q", head, 0x20, 0x40)
        struct.pack_into("<HH", head, 0x36, 56, len(aligns) + 1)
        phs = b"".join(struct.pack("<II6Q", 1, 5, 0, 0, 0, 0, 0, a) for a in aligns) + struct.pack("<II6Q", 6, 4, 0, 0, 0, 0, 0, 8)
    else:
        head = bytearray(0x34)
        head[:5] = b"\x7fELF\x01"
        struct.pack_into("<I", head, 0x1C, 0x34)
        struct.pack_into("<HH", head, 0x2A, 32, len(aligns))
        phs = b"".join(struct.pack("<8I", 1, 0, 0, 0, 0, 0, 5, a) for a in aligns)
    return bytes(head) + phs


def self_test() -> None:
    assert elf_load_alignments(_elf(True, [0x4000, 0x10000])) == [0x4000, 0x10000]
    assert elf_load_alignments(_elf(False, [0x1000])) == [0x1000]
    with tempfile.NamedTemporaryFile(suffix=".aab") as f:
        with zipfile.ZipFile(f.name, "w") as z:
            z.writestr("base/lib/arm64-v8a/libgood.so", _elf(True, [0x4000, 0x4000]))
            z.writestr("base/lib/arm64-v8a/libold.so", _elf(True, [0x4000, 0x1000]))
            z.writestr("base/lib/armeabi-v7a/libv7.so", _elf(False, [0x1000]))
            z.writestr("base/assets/flutter_assets/x.so.txt", b"not a library")
        bad = misaligned_libs(f.name)
    assert [b.split(" ")[0] for b in bad] == ["base/lib/arm64-v8a/libold.so", "base/lib/armeabi-v7a/libv7.so"], bad
    with tempfile.NamedTemporaryFile(suffix=".aab") as f:
        with zipfile.ZipFile(f.name, "w") as z:
            z.writestr("BUNDLE-METADATA/com.android.tools.build.debugsymbols/arm64-v8a/libflutter.so.sym", b"")
        missing = missing_metadata(f.name)
    assert len(missing) == 2 and "libapp.so" in missing[0] and "proguard.map" in missing[1], missing
    notes = "# Release notes\n\n## 0.1.0+2\nFirst release.\n\n## 0.1.0+1\nOld.\n"
    assert notes_entry(notes, "0.1.0+2") == "First release."
    assert notes_entry(notes, "0.1.0+1") == "Old."
    assert notes_entry(notes, "0.1.0+3") is None
    assert notes_entry(notes, "0.1.0") is None, "a version prefix is not a match"
    print("check_release self-test: ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        sys.exit(0)
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    found = check(*sys.argv[1:])
    for p in found:
        print(f"✗ {p}")
    if found:
        sys.exit(1)
    print(f"✓ {sys.argv[1]}: upload-signed, Readle's AdMob id, not debuggable, target SDK ok, 16 KB aligned, stripped (symbols + R8 mapping kept), notes ok")
