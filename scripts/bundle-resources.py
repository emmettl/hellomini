"""Copy resources of local targets belonging to HelloMini, excluding test bundles."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

# The toolchain names each bundle in its generated accessor; read it rather than guess.
# Native builds write `Bundle.main.bundleURL.appendingPathComponent("Name.bundle")`.
# Swift Build, the default from SwiftPM 6.4, writes `let bundleName = "Name"`.
ACCESSOR_PATTERNS = [
    re.compile(r'Bundle\.main\.bundleURL\.appendingPathComponent\("([^"/]+)\.bundle"\)'),
    re.compile(r'let bundleName = "([^"/]+)"'),
]


def find_accessor(binary_directory, c99name):
    """Locate a target's generated accessor in the native or Swift Build layout."""
    native = binary_directory / f"{c99name}.build/DerivedSources/resource_bundle_accessor.swift"
    if native.is_file():
        return native
    # Swift Build pairs out/Products/<Configuration> with out/Intermediates.noindex/*/<Configuration>.
    intermediates = binary_directory.parent.parent / "Intermediates.noindex"
    pattern = f"*/{binary_directory.name}/{c99name}-*.build/DerivedSources/resource_bundle_accessor.swift"
    matches = sorted(intermediates.glob(pattern))
    if len(matches) != 1:
        raise RuntimeError(f"Expected one SwiftPM bundle accessor for {c99name}, found {len(matches)}")
    return matches[0]


def bundle_name(accessor):
    text = accessor.read_text()
    for pattern in ACCESSOR_PATTERNS:
        match = pattern.search(text)
        if match:
            return match.group(1) + ".bundle"
    raise RuntimeError(f"Unsupported SwiftPM bundle accessor: {accessor}")


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
        # MiniResourceBundle resolves the copied bundle from the signed app's Contents/Resources.
        name = bundle_name(find_accessor(binary_directory, target["c99name"]))
        source = binary_directory / name
        if not source.is_dir():
            raise RuntimeError(f"Missing resource bundle {source}")
        shutil.copytree(source, resources_directory / name, dirs_exist_ok=True)


if __name__ == "__main__":
    package = json.loads(subprocess.check_output(["swift", "package", "describe", "--type", "json"]))
    copy_resources(package, Path(sys.argv[1]), Path(sys.argv[2]))
