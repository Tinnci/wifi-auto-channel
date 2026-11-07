"""Check packaging and run policy regressions when a host ucode is available."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PACKAGE = Path(__file__).resolve().parents[1]


class WifiAutoChannelTests(unittest.TestCase):
    def test_ax5_defaults_and_upstream_pin(self):
        config = (PACKAGE / "files/wifi-auto-channel.config").read_text()
        radio0 = config.split("config radio 'radio0'", 1)[1].split("config radio", 1)[0]
        radio1 = config.split("config radio 'radio1'", 1)[1]
        self.assertIn("option enabled '0'", radio0)
        for setting in ("enabled '1'", "idle_seconds '300'", "channels '1 6 11'",
                        "cooldown '3600'", "dfs_allowed '0'"):
            self.assertIn("option " + setting, radio1)
        recipe = (PACKAGE / "Makefile").read_text()
        self.assertRegex(recipe, r"# Upstream commit [0-9a-f]{40}\n")
        for dependency in ("ucode-mod-nl80211", "ucode-mod-ubus", "iw", "coreutils-timeout"):
            self.assertIn("+" + dependency, recipe)

    @unittest.skipUnless(shutil.which("make"), "make required for package install check")
    def test_package_installs_controller_and_policy(self):
        recipe = (PACKAGE / "Makefile").read_text()
        install = recipe.split("define Package/wifi-auto-channel/install\n", 1)[1]
        install = install.split("\nendef", 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            staging = root / "staging"
            runner = root / "install.mk"
            runner.write_text(
                "INSTALL_DIR:=mkdir -p\nINSTALL_BIN:=install -m 0755\n"
                "INSTALL_CONF:=install -m 0600\nINSTALL_DATA:=install -m 0644\n"
                "define install_package\n" + install + "\nendef\nall:\n"
                f"\t$(call install_package,{staging})\n"
            )
            subprocess.run(["make", "-f", str(runner)], cwd=PACKAGE,
                           check=True, capture_output=True)
            self.assertEqual((staging / "usr/sbin/wifi-auto-channel").read_bytes(),
                             (PACKAGE / "files/wifi-auto-channel.uc").read_bytes())
            self.assertEqual((staging / "usr/sbin/wifi-auto-channel").stat().st_mode & 0o777,
                             0o755)
            for module in ("channel.uc", "policy.uc"):
                path = Path("usr/share/ucode/wifi-auto-channel") / module
                self.assertEqual((staging / path).read_bytes(),
                                 (PACKAGE / "files" / path).read_bytes())

    @unittest.skipUnless(shutil.which("ucode"), "ucode required for host policy tests")
    def test_ucode_regressions(self):
        modules = str(PACKAGE / "files/usr/share/ucode/*.uc")
        for name in ("test_channel.uc", "test_policy.uc"):
            with self.subTest(name=name):
                subprocess.run(["ucode", "-L", modules, str(PACKAGE / "tests" / name)],
                               check=True, capture_output=True, timeout=30)


if __name__ == "__main__":
    unittest.main()
