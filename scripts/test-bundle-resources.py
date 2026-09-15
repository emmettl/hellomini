"""Exercise app resource bundling against both SwiftPM build layouts."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("bundle_resources", Path(__file__).with_name("bundle-resources.py"))
bundle_resources = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bundle_resources)

NATIVE_ACCESSOR = 'let buildPath = Bundle.main.bundleURL.appendingPathComponent("HelloMini_MiniUI.bundle").path\n'
SWIFT_BUILD_ACCESSOR = 'static nonisolated let module: Bundle = {\n        let bundleName = "HelloMini_MiniUI"\n'
PACKAGE = {"targets": [
    {"name": "MiniUI", "c99name": "MiniUI", "product_memberships": ["HelloMini"], "resources": [{"path": "x"}]},
    {"name": "MiniUITests", "c99name": "MiniUITests", "resources": [{"path": "y"}]},
    {"name": "MiniCore", "c99name": "MiniCore", "product_memberships": ["HelloMini"]},
]}


class BundleResourcesTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="hello-mini-bundle-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.app = self.root / "dist/Hello Mini.app"

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def make_bundle(self, products, name, marker):
        self.write(products / name / "Contents/Resources/marker.txt", marker)

    def copied_marker(self, name="HelloMini_MiniUI.bundle"):
        return (self.app / "Contents/Resources" / name / "Contents/Resources/marker.txt").read_text()

    def test_native_layout_copies_member_bundles_and_removes_stale_ones(self):
        products = self.root / ".build/arm64-apple-macosx/release"
        self.write(products / "MiniUI.build/DerivedSources/resource_bundle_accessor.swift", NATIVE_ACCESSOR)
        self.make_bundle(products, "HelloMini_MiniUI.bundle", "native")
        self.make_bundle(products, "HelloMini_MiniUITests.bundle", "test")
        self.write(self.app / "Contents/Resources/HelloMini_Removed.bundle/old.txt", "stale")
        bundle_resources.copy_resources(PACKAGE, products, self.app)
        self.assertEqual(self.copied_marker(), "native")
        self.assertEqual(sorted(p.name for p in (self.app / "Contents/Resources").glob("*.bundle")),
                         ["HelloMini_MiniUI.bundle"])

    def test_swift_build_layout_uses_the_matching_configuration(self):
        out = self.root / ".build/out"
        products = out / "Products/Release"
        for configuration in ["Debug", "Release"]:
            self.write(out / f"Intermediates.noindex/HelloMini.build/{configuration}/MiniUI-t.build/DerivedSources/"
                       "resource_bundle_accessor.swift", SWIFT_BUILD_ACCESSOR)
            self.write(out / f"Intermediates.noindex/HelloMini.build/{configuration}/MiniUITests-p.build/"
                       "DerivedSources/resource_bundle_accessor.swift", SWIFT_BUILD_ACCESSOR)
            self.make_bundle(out / "Products" / configuration, "HelloMini_MiniUI.bundle", configuration)
        bundle_resources.copy_resources(PACKAGE, products, self.app)
        self.assertEqual(self.copied_marker(), "Release")

    def test_unrecognised_or_missing_output_fails_loudly(self):
        products = self.root / ".build/out/Products/Release"
        products.mkdir(parents=True)
        with self.assertRaisesRegex(RuntimeError, "found 0"):
            bundle_resources.copy_resources(PACKAGE, products, self.app)
        accessor = (self.root / ".build/out/Intermediates.noindex/HelloMini.build/Release/MiniUI-t.build/"
                    "DerivedSources/resource_bundle_accessor.swift")
        self.write(accessor, "let somethingElse = 1\n")
        with self.assertRaisesRegex(RuntimeError, "Unsupported"):
            bundle_resources.copy_resources(PACKAGE, products, self.app)
        self.write(accessor, SWIFT_BUILD_ACCESSOR)
        with self.assertRaisesRegex(RuntimeError, "Missing resource bundle"):
            bundle_resources.copy_resources(PACKAGE, products, self.app)


if __name__ == "__main__":
    unittest.main()
