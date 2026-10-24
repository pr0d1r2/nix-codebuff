DRAFT INPUT. This file is the prompt for the first spec run of this repository.
Once that run lands SPEC.md and its node specs, they are the law; where
they differ from this file, they win. Written 2026-10-24 by an agent
working in nix-orca, from the owner's decision there (nix-orca root T18,
D26), as a handoff to a separate session.

Paradigm: paradigm (`github.com/pr0d1r2/paradigm`), the newest commit
when the run starts (fda10ea on 2026-10-24), with its language pages
`docs/NIX.md` and `docs/SHELL.md`. This repository conforms to the
paradigm process in full: the spec first, a gate laid before product
code, one change per commit, tests before scripts. Process, guardrail
roster and shared conventions come from there; this file states only the
product and its deviations.

nix-codebuff

Codebuff, the AI coding agent CLI (`github.com/CodebuffAI/codebuff`), as
a Nix flake on the fleet's pinned nixpkgs, with its version frozen by
hash: no download at run time. Shaped like `github.com/pr0d1r2/nix-hk`
(read its SPEC.md, flake.nix, pkgs/ and scripts/ first).

# Problem and goals

nixpkgs' `codebuff` (1.0.674 in the fleet's pin, MIT) packages the npm
package, which is only a launcher: on first run it downloads the real CLI
for the platform into the user's config dir, and it checks the registry
for a newer version on every start. So the nix package is neither frozen
nor reproducible, and it fails offline. nix-orca leaves codebuff out of
its agent set for that reason; the owner wants it in, frozen.

Goals:

1. `packages.<system>.codebuff` (and `default`): the real Codebuff CLI
   binary at a pinned version, fetched by hash at build time, for
   aarch64-darwin, x86_64-darwin, x86_64-linux and aarch64-linux.
   `codebuff` and `cb` on PATH, as the npm package names them.
2. `overlays.default` adds exactly `codebuff`.
3. Nothing at run time downloads, replaces or updates the binary. If the
   CLI self-updates or checks for updates, find the switch that turns
   it off (environment variable, config, flag) and set it in a wrapper;
   if there is none, document it and patch only if needed.
4. A bump script and workflow that move to the newest stable release and
   rewrite every platform's hash, refusing a release that lacks a
   platform's asset.
5. Built in CI, cached on cachix `pr0d1r2` (Linux).

# Upstream facts, measured 2026-10-24

- npm `codebuff` 1.0.688 (2026-09-08) is the launcher: `index.js`,
  `launcher.js`, `http.js`; dependency `tar`. `launcher.js` downloads
  `https://codebuff.com/api/releases/download/<version>/codebuff-<target>.tar.gz`
  (`NEXT_PUBLIC_CODEBUFF_APP_URL` overrides the host) and checks
  `https://registry.npmjs.org/codebuff/latest` for updates.
- That URL redirects to GitHub release assets of
  `github.com/CodebuffAI/codebuff-community` (public, MIT; repository id
  921429448). Its releases are tagged `v<version>` (v1.0.688,
  v1.0.687, …, not prereleases), each with
  `codebuff-{darwin-arm64,darwin-x64,linux-arm64,linux-x64,
  linux-x64-baseline,win32-x64,win32-x64-baseline}.tar.gz`.
- `linux-x64-baseline` is the build for CPUs without AVX2; the launcher
  picks it when `/proc/cpuinfo` lacks avx2. Decide how the flake offers
  it (an override, a second package), and record the default.
- Unknown until measured: whether the binary is a Bun or Node single
  executable, whether Linux needs `autoPatchelfHook` (dynamic glibc) or
  is static, whether darwin needs re-signing after unpacking (it must
  not be modified if it is signed; check with `codesign -dv`), whether it
  writes outside `$HOME/.config`, and whether it sends telemetry and how
  to turn that off.
- Main repository licence: Apache-2.0; the release repository: MIT. The
  spec run decides the package's `meta.license` from the binary's own
  terms.

# Decisions

D1. One input: `nixpkgs-lock`, `nixpkgs.follows =
    "nixpkgs-lock/nixpkgs"`, as nix-hk.
D2. Fetch the release asset from `codebuff-community` directly by version
    and hash (fetchurl of the GitHub asset URL), not through codebuff.com,
    so the source is the tagged release. Record each hash's source.
D3. Never modify a signed darwin binary. Linux may be patched only to
    resolve its interpreter and libraries.
D4. Frozen: no run-time download or self-update; checks prove it (run
    `codebuff --version` in the sandbox with no network, and assert it
    does not try to fetch).
D5. Bump: newest non-prerelease `v*` tag of codebuff-community; all
    platforms' hashes in one sources file, written only by the bump;
    a missing asset refuses the bump.
D6. Cache: Linux outputs to cachix `pr0d1r2` from CI only.
D7. Public from the start (the owner's decision). No private repository
    is ever named in committed text.
D8. Consumer: nix-orca adds it to its agent set (an option per agent,
    on by default, nix-orca root T18) in its own PR once this flake is
    released. Not part of this repository's work.

# Out of scope

Windows, the launcher package itself, and Codebuff's other products.
