# The flake checks (nix §I): each script check runs one script from
# scripts/checks/, loaded by path into the store, never inlined (nix §C,
# `docs/SHELL.md`); the runCommand body is that one call and `touch $out`.
# Every tool comes from `pkgs`, the flake's own pinned nixpkgs (root V1).
# The scripts make their own fresh HOME (nix §C). `overlay` and `meta`
# are nix assertions with no script: a false one is an eval error that
# names the rule.
{
  pkgs,
  codebuff,
  # x86_64-linux only (root §C); null elsewhere.
  codebuff-baseline ? null,
  overlay,
}:

let
  inherit (pkgs) lib;

  # The per-check inputs (nix §C). The ELF branch of untouched needs GNU
  # readelf and objcopy, on Linux only (R17).
  inputs = {
    frozen = with pkgs; [
      socat
      coreutils
      findutils
      gnused
      gnugrep
    ];
    tree-sitter = with pkgs; [
      coreutils
      gnused
      gnugrep
    ];
    untouched =
      with pkgs;
      [
        gnutar
        gzip
        diffutils
        coreutils
      ]
      ++ lib.optional stdenv.hostPlatform.isLinux binutils;
    layout = with pkgs; [
      findutils
      gnused
      gnugrep
    ];
  };

  # One script check: NAME is the derivation and check name, SCRIPT the
  # file under scripts/checks/, ARGS its command line.
  run =
    name: script: args:
    pkgs.runCommand name {
      nativeBuildInputs = inputs.${script};
    } "${pkgs.runtimeShell} ${../scripts/checks + "/${script}.sh"} ${args} && touch $out";

  # frozen (both entry points), tree-sitter, untouched, layout for one
  # package; SUFFIX tells the baseline's apart.
  scriptChecks =
    suffix: pkg:
    let
      v = pkg.version;
    in
    {
      "frozen${suffix}" = run "frozen${suffix}" "frozen" "${pkg}/bin/codebuff ${v}";
      "frozen-cb${suffix}" = run "frozen-cb${suffix}" "frozen" "${pkg}/bin/cb ${v}";
      "tree-sitter${suffix}" = run "tree-sitter${suffix}" "tree-sitter" "${pkg}/bin/codebuff";
      "untouched${suffix}" = run "untouched${suffix}" "untouched" "${pkg} ${pkg.src}";
      "layout${suffix}" = run "layout${suffix}" "layout" "${pkg}";
    };

  # A derivation that exists only when every rule holds; else an eval
  # error listing the rules that failed.
  assertion =
    name: rules:
    let
      failed = lib.filterAttrs (_: ok: !ok) rules;
    in
    if failed == { } then
      pkgs.runCommand name { } "touch $out"
    else
      throw "${name}: ${lib.concatStringsSep "; " (lib.attrNames failed)}";

  # pkgs:V5.
  meta =
    suffix: pkg:
    assertion "meta${suffix}" {
      "meta.license is not asl20 (pkgs:V5)" = (pkg.meta.license.spdxId or null) == "Apache-2.0";
      "meta.sourceProvenance is not [ binaryNativeCode ] (pkgs:V5)" =
        (pkg.meta.sourceProvenance or null) == [ lib.sourceTypes.binaryNativeCode ];
      "meta.mainProgram is not codebuff (pkgs:V5)" = (pkg.meta.mainProgram or null) == "codebuff";
    };
in
scriptChecks "" codebuff
// {
  meta = meta "" codebuff;

  # Root V4: the overlay adds exactly codebuff (its values stay lazy), and
  # the package it adds is the flake's own.
  overlay = assertion "overlay" {
    "attrNames (overlay {} {}) is not [ codebuff ] (root V4)" =
      builtins.attrNames (overlay { } { }) == [ "codebuff" ];
    "(pkgs.extend overlay).codebuff is not the flake's codebuff (root V4)" =
      (pkgs.extend overlay).codebuff.outPath == codebuff.outPath;
  };
}
// lib.optionalAttrs (codebuff-baseline != null) (
  scriptChecks "-baseline" codebuff-baseline
  // {
    meta-baseline = meta "-baseline" codebuff-baseline;
  }
)
