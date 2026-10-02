#!/usr/bin/env python3
"""Regression fixtures for the v5 artifact gate; no router or firmware build.

Run with FWTOOL=/path/to/host/fwtool python3 -m unittest discover -s tests -v.
The tiny tar payloads test validation logic, not bootability or Full Cone runtime.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "immortalwrt-mediatek-filogic-netcore_n60-pro"
IMAGE = PREFIX + "-squashfs-sysupgrade.bin"
MANIFEST = PREFIX + ".manifest"
PACKAGES = """firewall4 libnftnl11 nftables-json kmod-nft-nat iptables-nft
kmod-mt_wifi kmod-warp kmod-mediatek_hnat luci-app-mtwifi-cfg
luci-app-turboacc-mtk luci-app-eqos-mtk luci-app-openclash
luci-theme-argon luci-app-argon-config mtk-smp mtkhqos_util
kmod-pppoe ppp-mod-pppoe kmod-usb3 kmod-usb-storage kmod-usb-storage-uas""".split()


class FirmwareGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fwtool = Path(os.environ["FWTOOL"]).resolve()
        if not cls.fwtool.is_file():
            raise RuntimeError("FWTOOL must point to a real host fwtool binary")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.out = Path(self.temp.name)
        self.metadata = {
            "metadata_version": "1.1", "compat_version": "1.0",
            "supported_devices": ["netcore,n60-pro"],
            "version": {"target": "mediatek/filogic", "board": "netcore_n60-pro",
                        "revision": "r0-fixture", "version": "24.10-SNAPSHOT"},
        }
        self.profiles = {
            "target": "mediatek/filogic", "linux_kernel": {"version": "6.6.133"},
            "version_code": "r0-fixture", "version_number": "24.10-SNAPSHOT",
            "profiles": {"netcore_n60-pro": {
                "supported_devices": ["netcore,n60-pro"],
                "images": [{"type": "sysupgrade", "name": IMAGE}],
            }},
        }
        (self.out / MANIFEST).write_text(
            "kernel - 6.6.133~fixture-r1\n" + "".join(p + " - fixture\n" for p in PACKAGES))
        (self.out / "config.buildinfo").write_text(
            "CONFIG_TARGET_mediatek_filogic_DEVICE_netcore_n60-pro=y\n")
        self.write_image()

    def write_image(self, board="netcore_n60-pro"):
        top = "sysupgrade-netcore_n60-pro"
        with tarfile.open(self.out / IMAGE, "w", format=tarfile.USTAR_FORMAT) as tar:
            directory = tarfile.TarInfo(top)
            directory.type = tarfile.DIRTYPE
            tar.addfile(directory)
            for name, data in (
                ("CONTROL", f"BOARD={board}\n".encode()),
                ("kernel", bytes.fromhex("d00dfeed") + b"fixture"),
                ("root", b"hsqsfixture"),
            ):
                entry = tarfile.TarInfo(f"{top}/{name}")
                entry.size = len(data)
                tar.addfile(entry, io.BytesIO(data))
        metadata_file = self.out / "metadata.json"
        metadata_file.write_text(json.dumps(self.metadata))
        subprocess.run([str(self.fwtool), "-I", str(metadata_file), str(self.out / IMAGE)],
                       check=True, capture_output=True)
        digest = hashlib.sha256((self.out / IMAGE).read_bytes()).hexdigest()
        self.profiles["profiles"]["netcore_n60-pro"]["images"][0]["sha256"] = digest
        self.write_profiles()
        (self.out / "sha256sums").write_text(f"{digest}  {IMAGE}\n")

    def write_profiles(self):
        (self.out / "profiles.json").write_text(json.dumps(self.profiles))

    def check(self, expected_error=None):
        result = subprocess.run([
            "python3", str(ROOT / "scripts/verify-firmware.py"),
            "--output-dir", str(self.out), "--fwtool", str(self.fwtool),
        ], capture_output=True, text=True)
        output = result.stdout + result.stderr
        if expected_error is None:
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("Artifact checks passed", output)
        else:
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn(expected_error, output)

    def test_device_specific_manifest_passes_without_generic_manifest(self):
        self.assertFalse((self.out / "immortalwrt-mediatek-filogic.manifest").exists())
        self.check()

    def test_generic_manifest_cannot_substitute_for_device_manifest(self):
        (self.out / MANIFEST).rename(self.out / "immortalwrt-mediatek-filogic.manifest")
        self.check("missing device manifest")

    def test_v5_packages_and_driver_are_required(self):
        original = (self.out / MANIFEST).read_text()
        for package in ("iptables-nft", "luci-theme-argon", "luci-app-argon-config", "kmod-warp"):
            with self.subTest(package=package):
                (self.out / MANIFEST).write_text(original.replace(package + " - fixture\n", ""))
                self.check("required package missing: " + package)

    def test_legacy_fullcone_and_open_wifi_are_rejected(self):
        original = (self.out / MANIFEST).read_text()
        for package in ("kmod-ipt-fullconenat", "iptables-mod-fullconenat",
                        "ip6tables-mod-fullconenat", "kmod-mt7915e"):
            with self.subTest(package=package):
                (self.out / MANIFEST).write_text(original + package + " - fixture\n")
                self.check("forbidden package present: " + package)

    def test_second_sysupgrade_is_rejected(self):
        (self.out / "other-sysupgrade.bin").write_bytes(b"fixture")
        self.check("ambiguous sysupgrade images")

    def test_second_device_is_rejected(self):
        self.profiles["profiles"]["other_device"] = {}
        self.write_profiles()
        self.check("expected only the N60 Pro profile")

    def test_bad_checksum_is_rejected(self):
        (self.out / "sha256sums").write_text("0" * 64 + "  " + IMAGE + "\n")
        self.check("image SHA-256 differs from sha256sums")

    def test_wrong_embedded_device_with_valid_hashes_is_rejected(self):
        self.metadata["supported_devices"] = ["wrong,device"]
        self.write_image()
        self.check("image metadata device mismatch")

    def test_wrong_tar_board_with_valid_metadata_and_hashes_is_rejected(self):
        self.write_image(board="wrong_device")
        self.check("sysupgrade CONTROL board mismatch")


if __name__ == "__main__":
    unittest.main()
