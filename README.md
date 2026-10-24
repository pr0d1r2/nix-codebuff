# nix-codebuff

The [Codebuff](https://www.codebuff.com) CLI, an AI coding agent, as a nix
flake: upstream's real `codebuff` binary at a pinned version, fetched by hash,
for four systems, on the fleet nixpkgs pin
([`nixpkgs-lock`](https://github.com/pr0d1r2/nixpkgs-lock)). It is frozen: it
downloads nothing at run time, never updates itself and never checks for
updates. `codebuff` and `cb` land on your `PATH`.

Pinned: Codebuff 1.0.688, the newest stable upstream release as of 2026-10-24.

**Status, as of 2026-10-24: pre-release.** The `aarch64-darwin` package builds,
and its flake checks build and pass on an Apple Silicon Mac. All four systems
evaluate. Not done yet: the Linux and `x86_64-darwin` builds, running CI (the workflows are written), the binary
cache, and publishing this repository on GitHub. Until then the `github:` URLs
below do not resolve.

## Why this exists

nixpkgs already has a `codebuff`, but it is not the CLI. At the fleet pin
(nixpkgs 26.05 `da6dc0e`, checked 2026-10-24) it is version 1.0.674 of the npm
package, and that package is only a launcher. On first start it downloads the
real binary from `codebuff.com` into `~/.config/manicode/`; on every start it
asks `registry.npmjs.org` for a newer version and updates itself. So the nix
store holds a small script, and what actually runs is whatever the network
served that day. It does not work offline, and two machines on the same
nixpkgs rev can run different Codebuff versions.

This flake packages the binary itself and leaves the launcher out.

## What is frozen, and how

**The binary is fetched at build time, by hash.** Upstream publishes one Bun
single-file executable per platform as a release asset of
[`CodebuffAI/codebuff-community`](https://github.com/CodebuffAI/codebuff-community),
tag `v<version>`. The package fetches the tarball from that GitHub release URL
and checks it against the SRI hash in
[`pkgs/codebuff/sources.json`](pkgs/codebuff/sources.json). It never uses the
`codebuff.com` download redirector or the npm package.

**There is no updater to switch off.** The download and self-update code lives
in the npm launcher only. A byte scan of the binary finds no release-download
URL, no npm registry lookup for `codebuff` and no `npm install -g codebuff`;
the only npm registry strings belong to the Bun runtime's own package manager.
The launcher is not packaged, so nothing on your machine can fetch a new
Codebuff.

**The binary is upstream's.** On darwin it is the tarball member byte for byte:
copied with `install -m755`, not stripped, not re-signed, no
`install_name_tool`. On Linux only the ELF interpreter (and the rpath, if it
must) is set by `autoPatchelfHook`, and nothing is stripped, because Bun keeps
its JavaScript payload in the `.bun` section.

**The wrapper closes the run-time fetch paths that remain.** `bin/codebuff` is
a `makeWrapper` script around `libexec/codebuff/codebuff`; `bin/cb` is a link
to it. These are the variables it sets or unsets:

| variable | value | what it closes |
| --- | --- | --- |
| `CODEBUFF_TREE_SITTER_WASM_PATH` | `$out/libexec/codebuff/tree-sitter.wasm` | intended to point at the packaged parser; see the note below |
| `CODEBUFF_RG_PATH` | the pinned ripgrep's `rg` (15.1.0 at the 2026-10-24 pin), as a default | code search, which otherwise throws `Ripgrep binary not found`: the tarball ships no `rg` |
| `BUN_BE_BUN` | unset | the executable acting as the `bun` CLI, `bun upgrade` and `bun install` included |
| `CODEBUFF_SHIP_LOGS` | `false`, only with `shipLogs = false` | log batches sent upstream; unset by default, so logs ship as upstream intends (see [Telemetry](#telemetry)) |

A note on the tree-sitter variable, measured in a nix build on 2026-10-24: the
binary ignores `CODEBUFF_TREE_SITTER_WASM_PATH`. It loads `tree-sitter.wasm`
from the current directory first, then from beside its own executable, and
only then falls back to downloading it from `unpkg.com` or `cdn.jsdelivr.net`.
What actually closes that download is the layout: the wasm sits next to the
binary in `libexec/codebuff/`, and the wrapper execs the binary there, so the
second lookup always finds it. The variable stays set as the documented intent.
One consequence: a `tree-sitter.wasm` in the directory you start `codebuff`
from is loaded instead of the packaged one.

`CODEBUFF_RG_PATH` is a default, so you can point it at another `rg` yourself.

**The flake checks prove it.** `nix flake check` runs, per system:

- `frozen` and `frozen-cb`: `codebuff --version` (and `cb --version`) with a
  fresh `HOME` and the proxy variables pointed at a loopback listener; it must
  print the pinned version, the listener must see no connection, and no
  executable, `*.tar.gz` or `*.part` may appear under `HOME`.
- `tree-sitter`: `codebuff --smoke-tree-sitter` loads the packaged wasm, not a
  URL.
- `untouched`: on darwin the binary equals the tarball member; on Linux the
  library list and the `.bun` section are unchanged by the patch.
- `layout`: `bin/` holds exactly `codebuff` and `cb`, `cb` resolves to
  `codebuff`, and the wrapper points the wasm variable at the libexec file,
  defaults `rg` to an existing executable, unsets `BUN_BE_BUN` and execs the
  libexec binary.
- `meta` and `overlay`: the licence and provenance metadata, and that the
  overlay adds `codebuff` and nothing else.

On `x86_64-linux` the baseline build has its own copy of each.

## Telemetry

**Telemetry cannot be fully switched off.** The binary sends usage events to
PostHog (`us.i.posthog.com`). The PostHog key, the host and the `prod`
environment are compiled into the binary as literals; nothing reads them from
the environment, and Codebuff's own code does not look at `DO_NOT_TRACK`. There
is no off switch, and this package does not patch the binary to add one.

Log shipping does have a switch. Upstream sends log batches unless
`CODEBUFF_SHIP_LOGS=false`; the package keeps upstream's behaviour by default,
and turns log shipping off when you ask:

```nix
pkgs.codebuff.override { shipLogs = false; }
```

That sets `CODEBUFF_SHIP_LOGS=false` in the wrapper. PostHog events are still
sent. If you need no telemetry at all, do not run this binary on a network
that reaches PostHog.

## The darwin signature

The darwin binary is upstream's, and upstream's signature is already broken.
As shipped in 1.0.688 (checked 2026-10-24), `codesign --verify` rejects both
darwin binaries with `invalid signature (code or signature have been
modified)`. The arm64 one is ad hoc and linker-signed; the x64 one carries
Bun's own Developer ID certificate. The package does not re-sign: re-signing
would change the bytes it promises to keep.

On Apple Silicon the binary runs anyway: in the nix build on 2026-10-24,
`codebuff --version` printed `1.0.688`. On Intel Macs this is not measured yet.

## Use it

Add the flake as an input, and make it follow your `nixpkgs-lock` so both
resolve the same nixpkgs rev:

```nix
inputs = {
  nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
  nixpkgs.follows = "nixpkgs-lock/nixpkgs";
  nix-codebuff.url = "github:pr0d1r2/nix-codebuff";
  nix-codebuff.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
};
```

The `follows` line is load-bearing. The flake has one input, `nixpkgs-lock`,
and takes its nixpkgs from there. A consumer that follows the same
`nixpkgs-lock` gets the same rev, so the cached Linux builds hit; an unfollowed
second nixpkgs forks the rev and you build locally instead.

Then either take the package directly:

```nix
nix-codebuff.packages.${system}.codebuff   # also .default
```

or add the overlay, which adds exactly `codebuff`:

```nix
nixpkgs.overlays = [ nix-codebuff.overlays.default ];
environment.systemPackages = [ pkgs.codebuff ];   # or home.packages
```

Or run it once:

```sh
nix run github:pr0d1r2/nix-codebuff -- --version
```

### Which build on x86_64-linux

Upstream builds the default Linux x64 binary for CPUs with AVX2, and a second
one, `linux-x64-baseline`, for CPUs without it. Upstream's launcher reads
`/proc/cpuinfo` and picks for you. A flake cannot: evaluation is pure and never
sees the machine it will run on. So the choice is yours:

- `codebuff`: the AVX2 build. Pick it on any x86_64 CPU that has AVX2.
- `codebuff-baseline`: the non-AVX2 build, `packages.x86_64-linux` only. Pick
  it on older or low-power CPUs, and on virtual machines that hide AVX2 from
  the guest.

To check, `grep -m1 -o avx2 /proc/cpuinfo` prints `avx2` when the CPU has it.
Through the overlay, the baseline is `pkgs.codebuff.override { baseline = true; }`.
Asking for the baseline on any other system is an evaluation error.

## Binary cache

```text
substituter: https://pr0d1r2.cachix.org
public key:  pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=
```

Only Linux is cached: `codebuff` and `codebuff-baseline` closures, pushed by
CI from `main`, never from a fork's pull request. Darwin is never pushed; nix
builds it on your Mac, which is a download from GitHub and a file copy. As of
2026-10-24 CI is not running yet, so the cache holds nothing for this flake.

**The flake's `nixConfig` is not enough on its own.** If your user is not in
`trusted-users`, nix ignores the substituter and builds locally, and says so
only as a warning:

```text
warning: ignoring untrusted substituter 'https://pr0d1r2.cachix.org', you are not a trusted user
```

An administrator adds the cache once, in `nix.conf` or the system
configuration:

```nix
nix.settings = {
  extra-substituters = [ "https://pr0d1r2.cachix.org" ];
  extra-trusted-public-keys = [
    "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
  ];
};
```

To confirm you are substituting, `nix build --max-jobs 0` fails rather than
falling back to a local build.

## Pin graph

```text
nixpkgs-lock ──> nix-codebuff ──> your flake
nixpkgs-lock ───────────────────> your flake   (the same rev, by follows)
```

Bump order: `nixpkgs-lock`, then this flake, then consumers. A consumer that
moves to a new `nixpkgs-lock` before this flake has been rebuilt there resolves
a rev nothing is cached for.

## State on disk

Codebuff keeps its configuration in `~/.config/manicode/`. On a fresh `HOME`, `codebuff --version` writes only
`~/.config/manicode/settings.json`, and it needs a writable `HOME` to do even
that (measured 2026-10-24). What the other commands write is not measured yet.
In a project, Codebuff reads `.gitignore`, `.codebuffignore` and
`.manicodeignore`.

## Bumping

```sh
scripts/bump.sh           # write the newest stable release into sources.json
scripts/bump.sh --check   # only say whether a newer one exists
```

The bump lists every release of `CodebuffAI/codebuff-community` and keeps tags
of the form `v<major>.<minor>.<patch>` that are neither drafts nor
prereleases. The repository also carries `freebuff-*` and `v*-beta.N` tags,
and GitHub's "Latest" points at a Freebuff release, so it never uses
`releases/latest`. It picks the highest version by number, never downgrades,
and refuses unless all five assets exist and each one's `nix store
prefetch-file` hash equals the sha256 digest GitHub reports. Only then does it
rewrite `sources.json`, the one file that holds hashes; it commits nothing.
Exit codes: 0 bumped (the version on stdout), 3 up to date, 1 refused, 2 usage.

A daily workflow, `.github/workflows/upstream.yml`, runs `scripts/bump.sh --check`
and fails when a newer release is out; until it can open pull requests, the
bump is run by hand. It is written but has not run yet: the repository is not
on GitHub (2026-10-24).

## Licence

The package declares `meta.license = lib.licenses.asl20`. The binary is
compiled from the `cli/` directory of
[`CodebuffAI/codebuff`](https://github.com/CodebuffAI/codebuff), which is
Apache-2.0 and has no licence of its own in `cli/package.json`. The release
repository is MIT, which covers its own files; the npm launcher is MIT too,
and is not shipped. nixpkgs' `codebuff` says MIT because it packages the
launcher. This reading is an agent decision of 2026-10-24, awaiting the owner's
review.

This repository's own licence is not decided yet; the owner chooses it before
release. Until then there is no `LICENSE` file.

## More

- [`SPEC.md`](SPEC.md) is the design, with every decision and measurement and
  its date. This page explains it and can lag behind it.
- [`docs/SECURITY.md`](docs/SECURITY.md): reporting a problem, and what the
  package trusts.
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md): the dev shell, the gate, and
  how changes land.
- [`docs/LLM-DISCLAIMER.md`](docs/LLM-DISCLAIMER.md): coding agents built this
  repository; its defect record.
