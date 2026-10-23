{
  lib,
  buildNpmPackage,
  nodejs,
  makeWrapper,
}:
# upstream's own lockfile lacks `resolved` entries, so this wraps the npm release;
# bump package.json, run `npm install --package-lock-only --ignore-scripts`, fix the hash
buildNpmPackage {
  pname = "brave-search-mcp-server";
  version = (lib.importJSON ./package.json).version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };

  npmDepsHash = "sha256-wNSDYCpjz1er5gOZxc9JChq/rRq57kLxnDtldoq3PB4=";
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp -r node_modules $out/lib/
    makeWrapper ${lib.getExe nodejs} $out/bin/brave-search-mcp-server \
      --add-flags $out/lib/node_modules/@brave/brave-search-mcp-server/dist/index.js
    runHook postInstall
  '';

  meta = {
    description = "MCP server for the Brave Search API";
    homepage = "https://github.com/brave/brave-search-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "brave-search-mcp-server";
  };
}
