#!/usr/bin/env python3
"""Check N60 Pro build artifacts without modifying or flashing the image."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile

DEVICE = "netcore_n60-pro"
SUPPORTED_DEVICE = "netcore,n60-pro"
TARGET = "mediatek/filogic"
PREFIX = f"immortalwrt-mediatek-filogic-{DEVICE}"
IMAGE_NAME = f"{PREFIX}-squashfs-sysupgrade.bin"
REQUIRED_PACKAGES = (
    "firewall4", "libnftnl11", "kmod-nft-nat", "iptables-nft",
    "kmod-mt_wifi", "kmod-warp", "kmod-mediatek_hnat",
    "luci-app-mtwifi-cfg", "luci-app-turboacc-mtk", "luci-app-eqos-mtk",
    "luci-app-openclash", "luci-theme-argon", "luci-app-argon-config",
    "mtk-smp", "mtkhqos_util",
    "kmod-pppoe", "ppp-mod-pppoe", "kmod-usb3",
    "kmod-usb-storage", "kmod-usb-storage-uas",
)
FORBIDDEN_PACKAGES = (
    "kmod-mt7915e", "kmod-mt7986-firmware", "mt7986-wo-firmware",
    "kmod-ipt-fullconenat", "iptables-mod-fullconenat", "ip6tables-mod-fullconenat",
    "wrtbwmon", "luci-app-wrtbwmon", "luci-app-passwall",
    "zerotier", "luci-app-zerotier",
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(out, fwtool):
    image = out / IMAGE_NAME
    require(image.is_file(), f"missing image: {IMAGE_NAME}")
    candidates = sorted(p.name for p in out.glob("*sysupgrade*"))
    require(candidates == [IMAGE_NAME], f"ambiguous sysupgrade images: {candidates}")
    profiles = json.loads((out / "profiles.json").read_text())
    require(profiles["target"] == TARGET, "profiles.json target mismatch")
    require(set(profiles["profiles"]) == {DEVICE}, "expected only the N60 Pro profile")
    profile = profiles["profiles"][DEVICE]
    require(profile["supported_devices"] == [SUPPORTED_DEVICE], "profile device mismatch")
    records = [entry for entry in profile["images"] if entry["type"] == "sysupgrade"]
    require(len(records) == 1 and records[0]["name"] == IMAGE_NAME, "profile image mismatch")

    with image.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    require(digest == records[0]["sha256"], "image SHA-256 differs from profiles.json")
    checksums = {}
    for line in (out / "sha256sums").read_text().splitlines():
        if line.strip():
            checksum, name = line.split(maxsplit=1)
            name = name.lstrip("*").removeprefix("./")
            require(name not in checksums, f"duplicate checksum entry: {name}")
            checksums[name] = checksum
    require(checksums.get(IMAGE_NAME) == digest, "image SHA-256 differs from sha256sums")
    print(f"OK image SHA-256: {digest}")

    manifest = {}
    manifest_path = out / f"{PREFIX}.manifest"
    require(manifest_path.is_file(), f"missing device manifest: {manifest_path.name}")
    for line in manifest_path.read_text().splitlines():
        package, version = line.split(" - ", 1)
        require(package not in manifest, f"duplicate manifest package: {package}")
        manifest[package] = version
    for package in REQUIRED_PACKAGES:
        require(package in manifest, f"required package missing: {package}")
    require(any(p in manifest for p in ("nftables-json", "nftables-nojson", "nftables")),
            "nftables missing from manifest")
    for package in FORBIDDEN_PACKAGES:
        require(package not in manifest, f"forbidden package present: {package}")
    kernel_version = profiles["linux_kernel"]["version"]
    require(manifest.get("kernel", "").startswith(kernel_version + "~"),
            "kernel version differs between profile and manifest")
    print(f"OK manifest: {manifest_path.name}; v5 MTK/WARP/HNAT, OpenClash, iptables-nft, Argon, PPPoE, USB; kernel {kernel_version}")

    config = (out / "config.buildinfo").read_text().splitlines()
    selected = [line for line in config if line.startswith("CONFIG_TARGET_")
                and "_DEVICE_" in line and line.endswith("=y")]
    require(selected == [f"CONFIG_TARGET_mediatek_filogic_DEVICE_{DEVICE}=y"],
            f"unexpected selected devices: {selected}")

    result = subprocess.run([str(fwtool), "-i", "-", str(image)],
                            check=True, capture_output=True, text=True)
    metadata = json.loads(result.stdout)
    require(metadata["supported_devices"] == [SUPPORTED_DEVICE], "image metadata device mismatch")
    require(metadata["version"]["target"] == TARGET, "image metadata target mismatch")
    require(metadata["version"]["board"] == DEVICE, "image metadata board mismatch")
    require(metadata["version"]["revision"] == profiles["version_code"], "image revision mismatch")
    require(metadata["version"]["version"] == profiles["version_number"], "image version mismatch")
    print(f"OK fwtool metadata: {SUPPORTED_DEVICE}, {TARGET}, {metadata['version']['revision']}")

    prefix = f"sysupgrade-{DEVICE}"
    with tarfile.open(image, "r:") as archive:
        members = archive.getmembers()
        names = [member.name for member in members]
        expected = {prefix, f"{prefix}/CONTROL", f"{prefix}/kernel", f"{prefix}/root"}
        require(len(names) == len(expected) and set(names) == expected, "unexpected sysupgrade tar layout")
        require(archive.getmember(prefix).isdir(), "sysupgrade top level is not a directory")
        for name in ("CONTROL", "kernel", "root"):
            member = archive.getmember(f"{prefix}/{name}")
            require(member.isfile() and member.size > 0, f"invalid {name} member")
        require(archive.getmember(f"{prefix}/CONTROL").size < 1024, "oversized CONTROL member")
        control = archive.extractfile(f"{prefix}/CONTROL").read().decode().strip()
        require(control == f"BOARD={DEVICE}", "sysupgrade CONTROL board mismatch")
        require(archive.extractfile(f"{prefix}/kernel").read(4) == bytes.fromhex("d00dfeed"),
                "kernel is not a FIT image")
        require(archive.extractfile(f"{prefix}/root").read(4) == b"hsqs", "root is not SquashFS")
    print("OK sysupgrade tar: board, FIT kernel, SquashFS root")
    print("Artifact checks passed. Full Cone runtime, device layout and configuration migration still require router-side checks.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", default="immortalwrt")
    parser.add_argument("--output-dir", type=Path, help="directory containing downloaded build outputs")
    parser.add_argument("--fwtool", type=Path, help="host fwtool executable")
    args = parser.parse_args()
    source = Path(args.source).resolve()
    out = (args.output_dir or source / "bin/targets/mediatek/filogic").resolve()
    fwtool = args.fwtool or Path(os.environ.get("FWTOOL", str(source / "staging_dir/host/bin/fwtool")))
    try:
        verify(out, fwtool.resolve())
    except (OSError, ValueError, KeyError, TypeError, tarfile.TarError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
