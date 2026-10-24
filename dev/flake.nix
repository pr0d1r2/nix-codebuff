{
  description = "nix-codebuff -- dev shell: gate tools pinned, git hooks installed on entry";

  # hk and the fleet tools are pushed to this cache. Without the substituter
  # every entry into the shell builds them from source.
  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # ONE nixpkgs: `nixpkgs-lock`'s, and every input follows it (dev V1). This
  # flake has its own lock, so none of these inputs reach a consumer's lock
  # (root §C: the root flake keeps its one input). Fleet tools are pinned to
  # tags, each bumped in its own commit.
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    nix-hk = {
      url = "github:pr0d1r2/nix-hk";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };

    # Spec form and spec operations (`mth`).
    microlith = {
      url = "github:pr0d1r2/microlith/v0.7.4";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # SPEC-DAG federation, budgets, waves.
    sherd = {
      url = "github:pr0d1r2/sherd/v0.5.4";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Per-file token ceilings.
    itok = {
      url = "github:pr0d1r2/itok/v0.3.1";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };
    # Hook guardrails materialised from `.pklith` (root T7).
    pklith = {
      url = "github:pr0d1r2/pklith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Workflows materialised from `.actlith` (root T12).
    actlith = {
      url = "github:pr0d1r2/actlith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # One language per file, 1:1 test mirror, TDD order (`xnl`).
    xenolith = {
      url = "github:pr0d1r2/xenolith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-hk,
      microlith,
      sherd,
      itok,
      pklith,
      actlith,
      xenolith,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      # The overlay makes `pkgs.hk` nix-hk's hk: the pin ships none.
      forAll =
        f: nixpkgs.lib.genAttrs systems (s: f (nixpkgs.legacyPackages.${s}.extend nix-hk.overlays.default));

      fleet = {
        inherit
          microlith
          sherd
          itok
          pklith
          actlith
          xenolith
          ;
      };

      # Fleet tools with no working build on a system (dev §C). The shell
      # still evaluates there and names the missing tools on entry; a gate
      # that needs one fails, never skips.
      unavailable = {
        x86_64-darwin = [
          "microlith"
          "itok"
          "pklith"
          "xenolith"
        ];
      };
      missing = system: unavailable.${system} or [ ];

      # The tools `pklith gen` names for this repository's checks, written to
      # `nix/pklith.nix` (root T7). Resolved against nixpkgs plus the fleet
      # inputs, the namespace pklith's catalog uses. Empty until it exists,
      # and on a system missing fleet tools, whose gates fail anyway.
      generated =
        pkgs: system:
        let
          file = ../nix/pklith.nix;
          catalog = pkgs // {
            microlith = microlith.packages.${system}.default;
            sherd = sherd.packages.${system}.default;
            itok = itok.packages.${system}.default;
          };
        in
        if missing system != [ ] || !builtins.pathExists file then [ ] else import file catalog;

      present =
        system:
        map (name: fleet.${name}.packages.${system}.default) (
          builtins.filter (name: !builtins.elem name (missing system)) (builtins.attrNames fleet)
        );
    in
    {
      devShells = forAll (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              # The gate runner, and the language its config is written in.
              pkgs.hk
              pkgs.pkl
              pkgs.git
              # Shell: tests, lint, format (`docs/SHELL.md`).
              pkgs.bats
              pkgs.shellcheck
              pkgs.shfmt
              # Nix: format, lint, dead code (`docs/NIX.md`).
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
              # Workflows, JSON, GitHub.
              pkgs.actionlint
              pkgs.jq
              pkgs.gh
            ]
            ++ present system
            ++ generated pkgs system;

            # Deterministic tool output across machines.
            LANG = "C.UTF-8";

            # Hooks and the missing fleet tools (dev V3):
            # scripts/dev/shell-hook.sh.
            shellHook = "bash ${../scripts/dev/shell-hook.sh} ${system} ${pkgs.lib.escapeShellArgs (missing system)}";
          };
        }
      );
    };
}
