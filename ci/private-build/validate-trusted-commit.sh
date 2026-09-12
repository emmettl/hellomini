#!/bin/bash
set -euo pipefail

checkout="${1:?Pass the freshly fetched source repository}"
requested_sha="${2:-}"
if [[ -z "$requested_sha" ]]; then
  requested_sha="$(git -C "$checkout" rev-parse refs/remotes/origin/main)"
fi
if ! [[ "$requested_sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo "Use a full 40-character commit SHA from main, not a branch or pull request ref." >&2
  exit 1
fi
commit="$(git -C "$checkout" rev-parse --verify "$requested_sha^{commit}")"
if ! git -C "$checkout" merge-base --is-ancestor "$commit" refs/remotes/origin/main; then
  echo "Refusing to build a commit that is not on the public repository's main branch." >&2
  exit 1
fi
printf '%s\n' "$commit"
