# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately, through GitHub's private
vulnerability reporting on this repository, not in a public issue. The
repository is not published yet (as of 2026-10-24); the reporting form
opens with it. Include what you ran, what happened, and what you
expected.

## Scope

This repository is packaging only: it fetches upstream's binary, installs
it, wraps it and checks it. In scope is anything that packaging gets
wrong:

- a run-time download, self-update or update check that the package
  claims to close and does not;
- a fetched asset that does not match its hash in
  `pkgs/codebuff/sources.json`, or a bump that writes a hash GitHub does
  not report;
- a path the wrapper sets that points outside the nix store, or a
  change to the binary the package promises not to make;
- anything that would let a fork's pull request or an unreviewed change
  reach the binary cache.

A vulnerability in Codebuff itself belongs to
[`CodebuffAI/codebuff`](https://github.com/CodebuffAI/codebuff), and one in
a release asset to
[`CodebuffAI/codebuff-community`](https://github.com/CodebuffAI/codebuff-community).
Report it there, and here only if this packaging makes it worse.

## What the package trusts

- **Upstream's release.** The binary is the release asset of
  `CodebuffAI/codebuff-community`, fetched from its GitHub URL by SRI hash.
  The bump writes a hash only when `nix store prefetch-file` and GitHub's
  sha256 digest agree. That proves the bytes are the ones GitHub serves
  for the tag; it does not prove who built them.
- **The binary as shipped.** On darwin it is installed byte for byte; on
  Linux only its ELF interpreter (and rpath, if needed) is changed. The
  package does not patch Codebuff's behaviour.
- **nixpkgs at the fleet pin**, through
  [`nixpkgs-lock`](https://github.com/pr0d1r2/nixpkgs-lock), for the
  wrapper and ripgrep.
- **The binary cache**, `pr0d1r2.cachix.org`, for Linux only, pushed by
  CI from `main`, never from a fork. CI is not running yet (as of
  2026-10-24), so nothing is pushed.

## Known facts to weigh

These are upstream behaviours the package documents and does not change.

- **Telemetry has no off switch.** The binary sends usage events to
  PostHog with a key and host compiled in, and does not read
  `DO_NOT_TRACK`. `shipLogs = false` stops log batches only. See the
  README's Telemetry section.
- **The darwin signatures are invalid as shipped.** For 1.0.688
  (checked 2026-10-24), `codesign --verify` rejects both darwin binaries
  with `invalid signature (code or signature have been modified)`. So
  the signature cannot tell you whether the binary was changed after
  upstream built it; the hash in `sources.json` is the only integrity
  check. The package does not re-sign. On Apple Silicon the binary runs
  regardless; on Intel Macs that is not measured yet.
- **A `tree-sitter.wasm` in the current directory wins.** The binary
  loads `tree-sitter.wasm` from the directory you start it in before the
  packaged copy. Starting `codebuff` in a directory you do not trust
  lets that directory supply the parser it runs.
- **The state directory** is `~/.config/manicode/`, outside the store,
  writable by you and by anything running as you.

Reporting the signature and telemetry facts upstream is planned and waits
for the owner's approval.
