"""Copy resources of local targets belonging to HelloMini, excluding test bundles."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


def copy_resources(package, binary_directory, app_directory):
    # The destination is a generated app: remove bundles from earlier target/resource sets.
    for previous in app_directory.glob("*.bundle"):
        if previous.is_symlink():
            previous.unlink()
        else:
            shutil.rmtree(previous)
    resources_directory = app_directory / "Contents/Resources"
    resources_directory.mkdir(parents=True, exist_ok=True)
    for previous in resources_directory.glob("*.bundle"):
        if previous.is_symlink():
            previous.unlink()
        else:
            shutil.rmtree(previous)
    for target in package["targets"]:
        if "HelloMini" not in target.get("product_memberships", []) or not target.get("resources"):
            continue
        accessor = binary_directory / f'{target["c99name"]}.build/DerivedSources/resource_bundle_accessor.swift'
        # Read the toolchain's bundle name; MiniResourceBundle resolves the signed app location.
        match = re.search(r'Bundle.main.bundleURL.appendingPathComponent\("([^"/]+\.bundle)"\)', accessor.read_text())
        if not match:
            raise RuntimeError(f"Unsupported SwiftPM bundle accessor: {accessor}")
        name = match.group(1)
        shutil.copytree(binary_directory / name, resources_directory / name, dirs_exist_ok=True)


if __name__ == "__main__":
    package = json.loads(subprocess.check_output(["swift", "package", "describe", "--type", "json"]))
    copy_resources(package, Path(sys.argv[1]), Path(sys.argv[2]))
