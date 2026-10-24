{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  versionCheckHook,
  glibc,
  ripgrep,
  # The non-AVX2 x86_64-linux build, upstream's `linux-x64-baseline`; the
  # flake exposes it as `codebuff-baseline` (root §C). Any other system
  # has no baseline build, so asking for one is an eval error.
  baseline ? false,
  # false sets CODEBUFF_SHIP_LOGS=false, so log batches are not sent. The
  # default keeps upstream behaviour (root §C, R10). PostHog telemetry
  # has no off switch either way: its key and host are baked in.
  shipLogs ? true,
}:

let
  # Every hash lives here, written only by scripts/bump.sh (pkgs:V6).
  sources = lib.importJSON ./sources.json;

  inherit (stdenvNoCC.hostPlatform) system;

  # nix system -> upstream release target (pkgs §C).
  targets = {
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
  };

  target =
    if baseline then
      "linux-x64-baseline"
    else
      targets.${system} or (throw "codebuff: no upstream build for ${system}");

  asset = sources.assets.${target};
in

# Thrown before mkDerivation, so the message is this one, not a platform
# mismatch from meta.platforms.
if baseline && system != "x86_64-linux" then
  throw "codebuff: baseline = true selects linux-x64-baseline, which exists only for x86_64-linux, not ${system}"
else

  stdenvNoCC.mkDerivation {
    pname = "codebuff";
    inherit (sources) version;

    # The tarball holds `codebuff` and `tree-sitter.wasm` at its top, no
    # directory (R2).
    src = fetchurl { inherit (asset) url hash; };
    sourceRoot = ".";

    nativeBuildInputs = [
      makeWrapper
    ]
    ++ lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;

    # Linux: the Bun binary NEEDs glibc's libraries only (R5), so the hook
    # sets PT_INTERP (and rpath if it must) and nothing else (pkgs:V2).
    buildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux (lib.getLib glibc);

    # Bun keeps its JS payload in the `.bun` ELF section and the `__BUN`
    # Mach-O segment (R3); strip would cut it. darwin: the binary is the
    # tarball member byte for byte, no install_name_tool, no codesign (D3).
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    # The wrapper execs the libexec binary, so process.execPath stays
    # there and the sibling tree-sitter.wasm lookup holds too. The env
    # closes the run-time fetch paths: tree-sitter wasm (R9), ripgrep
    # (R8), Bun's own CLI (R15).
    installPhase = ''
      runHook preInstall
      install -Dm755 codebuff $out/libexec/codebuff/codebuff
      install -Dm644 tree-sitter.wasm $out/libexec/codebuff/tree-sitter.wasm
      makeWrapper $out/libexec/codebuff/codebuff $out/bin/codebuff \
        --set CODEBUFF_TREE_SITTER_WASM_PATH $out/libexec/codebuff/tree-sitter.wasm \
        --set-default CODEBUFF_RG_PATH ${lib.getExe ripgrep} \
        --unset BUN_BE_BUN ${lib.optionalString (!shipLogs) "--set CODEBUFF_SHIP_LOGS false"}
      ln -s codebuff $out/bin/cb
      runHook postInstall
    '';

    # A wrong binary, or a payload the fixup broke, fails the build here.
    doInstallCheck = true;
    nativeInstallCheckInputs = [ versionCheckHook ];
    versionCheckProgramArg = "--version";
    # Even `--version` creates ~/.config before printing; the sandbox HOME
    # (/var/empty) is read-only, so the check gets a throwaway one.
    versionCheckKeepEnvironment = [ "HOME" ];
    preInstallCheck = ''
      export HOME=$(mktemp -d)
    '';

    passthru = { inherit sources; };

    meta = {
      description = "Codebuff CLI, an AI coding agent, as upstream's prebuilt binary";
      homepage = "https://www.codebuff.com";
      license = lib.licenses.asl20;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      mainProgram = "codebuff";
      platforms = if baseline then [ "x86_64-linux" ] else lib.attrNames targets;
    };
  }
