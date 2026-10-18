"""Update emmettl/tap/hellomini after publishing a stable, notarized GitHub release.

Usage: python3 scripts/update-homebrew-tap.py 0.8.0 [--dry-run]
Uses the host's gh authentication; never publishes a release or changes credentials.
"""

import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

REPOSITORY = "emmettl/hellomini"
TAP = "emmettl/homebrew-tap"
CASK = "Casks/hellomini.rb"
TEMPLATE = Path(__file__).resolve().parents[1] / "packaging/homebrew/hellomini.rb"


def gh(*arguments, stdin=None):
    return subprocess.run(["gh", *arguments], check=True, text=True, input=stdin,
                          stdout=subprocess.PIPE).stdout


def published_sha256(version):
    release = json.loads(gh("release", "view", f"v{version}", "--repo", REPOSITORY,
                            "--json", "tagName,isDraft,isPrerelease"))
    if release != {"tagName": f"v{version}", "isDraft": False, "isPrerelease": False}:
        raise ValueError("The requested release must be public and stable.")
    name = f"Hello-Mini-{version}-macos-arm64.zip"
    checksum = gh("release", "download", f"v{version}", "--repo", REPOSITORY,
                  "--pattern", name + ".sha256", "--output", "-").strip()
    match = re.fullmatch(r"([0-9a-f]{64})  " + re.escape(name), checksum)
    if not match:
        raise ValueError("The release checksum must name the exact versioned ZIP.")
    digest = match[1]
    manifest = json.loads(gh("release", "download", f"v{version}", "--repo", REPOSITORY,
                             "--pattern", name.removesuffix(".zip") + ".json", "--output", "-"))
    expected = {"version": version, "sha256": digest, "architecture": "arm64",
                "minimumMacOS": "26.0", "notarized": True, "signing": "Developer ID Application"}
    if any(manifest.get(key) != value for key, value in expected.items()):
        raise ValueError("The release manifest does not describe the expected notarized app.")
    with tempfile.TemporaryDirectory(prefix="hellomini-tap-") as directory:
        archive = Path(directory) / name
        gh("release", "download", f"v{version}", "--repo", REPOSITORY,
           "--pattern", name, "--output", str(archive))
        with archive.open("rb") as stream:
            hasher = hashlib.sha256()
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                hasher.update(chunk)
            actual = hasher.hexdigest()
        if actual != digest:
            raise ValueError("The published ZIP does not match its checksum.")
    return digest


def updated_cask(cask, version, digest):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("Invalid cask version or SHA-256.")
    for key, value in (("version", version), ("sha256", digest)):
        pattern = re.compile(rf'^(\s*){key} "[^"]*"$', re.MULTILINE)
        if len(pattern.findall(cask)) != 1:
            raise ValueError(f"The cask must have exactly one {key} line.")
        cask = pattern.sub(lambda match: f'{match[1]}{key} "{value}"', cask)
    return cask


def current_cask():
    # Listing the directory distinguishes a missing cask from auth/network errors.
    entries = json.loads(gh("api", f"repos/{TAP}/contents/Casks"))
    if not any(entry["path"] == CASK for entry in entries):
        return TEMPLATE.read_text(), None
    reply = json.loads(gh("api", f"repos/{TAP}/contents/{CASK}"))
    return base64.b64decode(reply["content"]).decode(), reply["sha"]


def commit(text, blob, version):
    body = {"message": f"Hello Mini {version}",
            "content": base64.b64encode(text.encode()).decode()}
    if blob:
        body["sha"] = blob  # GitHub rejects a concurrent edit rather than overwriting it.
    gh("api", "--method", "PUT", f"repos/{TAP}/contents/{CASK}", "--input", "-",
       stdin=json.dumps(body))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("version", help="published major.minor.patch version, without v")
    parser.add_argument("--dry-run", action="store_true", help="verify release and print cask without writing")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("Give a numeric major.minor.patch version, without v.")
    try:
        digest = published_sha256(args.version)
        cask, blob = current_cask()
        previous = re.search(r'^  version "([^"]+)"$', cask, re.MULTILINE)
        if blob and previous and tuple(map(int, previous[1].split('.'))) > tuple(map(int, args.version.split('.'))):
            raise ValueError("Refusing to downgrade the tap.")
        text = updated_cask(cask, args.version, digest)
        if args.dry_run:
            print(text, end="")
        elif blob and text == cask:
            print(f"{TAP} already has Hello Mini {args.version}.")
        else:
            commit(text, blob, args.version)
            print(f"{TAP}: {CASK} now {args.version} ({digest}).")
    except (ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Tap update stopped: {error}\n")


if __name__ == "__main__":
    main()
