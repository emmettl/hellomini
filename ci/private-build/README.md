# Hello Mini builds

Private build configuration for [Hello Mini](https://github.com/emmettl/hellomini).

The **Build on Mac Mini** workflow runs on the dedicated `hello-mini` runner. Dispatch it from `main`, leaving `source_sha` empty for the current public `main`, or supplying the full SHA of an earlier commit reachable from `main`. Commits from unmerged pull requests and other branches are rejected before their files are checked out or executed.

The workflow requires macOS 26.6+, Apple silicon, and Xcode 27 at `/Applications/Xcode.app`. It runs all checks including real Metal rendering, makes a release app bundle, verifies its ad-hoc signature, and uploads a ZIP for 14 days. It does not install or launch the build, change the running Hello Mini app, or perform notarization.

Keep this repository private and limit write access to trusted maintainers. The runner is registered only to this repository. Public pull requests run on GitHub-hosted machines in the source repository. Never add public PR triggers or check out untrusted PR code here. A commit on `main` is a trust decision: review changes before merging them.

Canonical setup files are kept under `ci/private-build/` in the public source repository. Changes to that template must be reviewed and copied into this repository; they are not automatically executed on the Mini.
