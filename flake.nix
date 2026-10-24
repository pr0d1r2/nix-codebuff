{
  description = "Codebuff CLI -- the upstream binary at a pinned version, frozen: no run-time download, no self-update";

  # CI pushes the Linux builds here (root §C). Without the substituter a
  # consumer builds them, which is only a fetch and a patch, but still slower.
  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # ONE input (root V1). nixpkgs-lock is the fleet's sole nixpkgs authority
  # and nixpkgs follows it, so a consumer that follows nixpkgs-lock too gets
  # the same nixpkgs rev, and the cached builds hit. Gate tools live in
  # dev/flake.nix, never here.
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in
    {
      packages = forAll (
        pkgs:
        let
          codebuff = pkgs.callPackage ./pkgs/codebuff/package.nix { };
        in
        {
          inherit codebuff;
          default = codebuff;
        }
        # The non-AVX2 build exists upstream for x86_64-linux only (root §C).
        // nixpkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          codebuff-baseline = pkgs.callPackage ./pkgs/codebuff/package.nix { baseline = true; };
        }
      );

      # Adds exactly `codebuff` (root V4).
      overlays.default = final: _prev: {
        codebuff = final.callPackage ./pkgs/codebuff/package.nix { };
      };
    };
}
