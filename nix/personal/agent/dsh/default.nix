{
  lib,
  stdenv,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  autoPatchelfHook,
  makeWrapper,
  fetchurl,
}:
let
  # node-addon-require-builtin pattern-matches node's machine code and only
  # recognizes the official builds, not nixpkgs' gcc-built node
  node = stdenv.mkDerivation (finalAttrs: {
    pname = "nodejs-official";
    version = "24.22.1";
    src = fetchurl {
      url = "https://nodejs.org/dist/v${finalAttrs.version}/node-v${finalAttrs.version}-linux-x64.tar.xz";
      hash = "sha256-bBcqmrZxj3uAH7WnvUhq8u5eMnWAhqBLhPzOKqdwleY=";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp bin/node $out/bin/
      runHook postInstall
    '';
    meta.mainProgram = "node";
  });
in
# upstream ships only through npm; bump package.json, run ./update.sh, fix the hash
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh";
  version = (lib.importJSON ./package.json).version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./pnpm-lock.yaml
      ./.npmrc
      ./plugins
    ];
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-UbALcvlX2oW/vtAsdKx3SxEuit4NuYcVYTHHn6SI6+s=";
  };

  # also what patchShebangs picks up
  nativeBuildInputs = [
    node
    pnpm_10
    pnpmConfigHook
    autoPatchelfHook
    makeWrapper
  ];
  # prebuilt native addons
  buildInputs = [ stdenv.cc.cc.lib ];
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-*.so.1" ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp -r node_modules $out/lib/
    mkdir -p $out/lib/node_modules/@kp2pml30
    cp -r plugins $out/lib/node_modules/@kp2pml30/dsh-plugins
    makeWrapper ${lib.getExe node} $out/bin/dsh \
      --set-default NODE_ENV production \
      --add-flags $out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js
    # bypasses dsh-tui's own launcher, which bootstraps and updates the profile through pnpm
    makeWrapper $out/bin/dsh $out/bin/dsh-tui \
      --set-default DSH_BUNDLED_SKILL_DIR $out/lib/node_modules/@deepseek-harness-tui/dsh-tui/guide \
      --add-flags "--profile dsh-tui"
    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Harness, a plugin-based coding agent, with the dsh-TUI frontend";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [ "x86_64-linux" ];
  };
})
