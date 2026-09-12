# Build pipeline

The public source repository is `emmettl/hellomini`. The private runner repository is `emmettl/hellomini-builds`.

## Public checks

`.github/workflows/ci.yml` runs on pushes to `main`, pull requests, and manual dispatches. It uses GitHub-hosted `macos-26` ARM runners with Xcode 26.6 explicitly selected. Jobs have read-only repository permissions, do not persist checkout credentials, and use commit-pinned actions.

The workflow runs `make check` (including Print Monitor tests in both debug and release configurations), builds a release app with `make app CONFIGURATION=release`, verifies its signature, and uploads `Hello-Mini-macos-arm64.zip`. Artifacts are retained for 14 days. `MINI_ALLOW_MISSING_METAL=1` permits the Teapot, Aquarium, and shared desk-scene Metal integration tests to be skipped only when the hosted machine has no Metal device. The other tests still run. Local checks and the physical Mini require all Metal tests.

## Private Mini builds

The configuration under `ci/private-build/` is copied to the root of `emmettl/hellomini-builds`, which must remain private. It is a template in this public repository, not an active public workflow. Keep private repository write access restricted to trusted maintainers.

The dedicated runner uses the custom `hello-mini` label alongside `self-hosted`, `macOS`, and `ARM64`. It is registered at repository scope to the private build repository only. Its macOS user needs an active login session for the SwiftUI rendering tests and the runner's LaunchAgent. Xcode 26.6 must be available at `/Applications/Xcode.app`; the workflow checks the selected toolchain before building.

Run **Build on Mac Mini** from the private repository's Actions page. Leave the SHA empty to build the current public `main`, or supply a full commit SHA reachable from that branch. The workflow fetches only `main`, validates the commit before checkout, runs all tests including Metal, builds a release bundle, and uploads a private artifact. Builds are serialized, have a 30-minute timeout, and remove their temporary source checkout afterward. They do not install or launch Hello Mini or interrupt the existing app.

From a machine with GitHub CLI access:

```sh
gh workflow run trusted-build.yml --repo emmettl/hellomini-builds
# Or select an already-reviewed commit on main:
gh workflow run trusted-build.yml --repo emmettl/hellomini-builds -f source_sha=FULL_COMMIT_SHA
```

Public PRs cannot dispatch this private workflow using their normal repository token. No private build credentials are stored in the public repository. Main-branch membership is the trust boundary, so review source changes before merging. Do not add public PR triggers or fetch PR refs in the private workflow. Changes to the public configuration template must be reviewed before copying them into the private build repository.

## Runner installation and maintenance

Use GitHub's **Settings → Actions → Runners → New self-hosted runner** in the private repository to obtain the official macOS ARM64 runner and a short-lived registration token. Verify the published SHA-256 before extracting it into a dedicated directory. Configure the URL as `https://github.com/emmettl/hellomini-builds`, name the runner `hello-mini`, add the `hello-mini` label, and use `_work` as its work directory. Install and start its LaunchAgent with `./svc.sh install` and `./svc.sh start` under the logged-in runner user. Keep registration tokens and generated runner credential files out of Git.

The runner's normal automatic updates remain enabled. Existing runners for other projects are independent. Before retiring this runner, stop and uninstall its service and remove its registration from the private repository. No signing identity, Apple account, or deployment credentials are needed for these builds.

Artifacts carry an ad-hoc signature and are development builds. The source is MIT licensed. The separate local `make release` path prepares a Developer ID-signed and notarized archive once the release machine has the required identity and Keychain profile. It never publishes automatically. See [Releasing](RELEASING.md); neither CI repository receives signing credentials through this change.

References: [GitHub runner security](https://docs.github.com/en/actions/reference/security/secure-use), [macOS runner images](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md), and [adding a self-hosted runner](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners).
