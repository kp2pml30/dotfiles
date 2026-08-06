{
  lib,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
}:
let
  version = "0.4.6";
  src = fetchFromGitHub {
    owner = "mcpjungle";
    repo = "MCPJungle";
    tag = version;
    hash = "sha256-XzszhbkQENeUgOOVBw7dsqZWR7hU3yLYOAclf3E9gy8=";
  };

  dashboard = buildNpmPackage {
    pname = "mcpjungle-dashboard";
    inherit version;
    # the whole tree: the dashboard aliases @repo-assets to ../../assets
    inherit src;
    sourceRoot = "${src.name}/web/dashboard";
    npmDepsHash = "sha256-zvsMx6OxVIWj4krYInhp9jmUD0tiLqzpIiiSB8kVHqY=";
    installPhase = ''
      cp -r dist $out
    '';
  };
in
buildGoModule {
  pname = "mcpjungle";
  inherit version src;

  vendorHash = "sha256-3uatBXXdQzqGuhFuLkpmoMkYYqUMt1dFqm7vuazMLqs=";

  # go:embed of internal/dashboardui/dist, normally produced by scripts/build-dashboard.sh
  preBuild = ''
    cp -r ${dashboard} internal/dashboardui/dist
  '';

  # export tests resolve `~`
  preCheck = ''
    export HOME=$TMPDIR
  '';

  ldflags = [
    "-s"
    "-w"
    "-X github.com/mcpjungle/mcpjungle/pkg/version.Version=${version}"
  ];

  meta = {
    description = "Gateway and registry for MCP servers";
    homepage = "https://github.com/mcpjungle/MCPJungle";
    license = lib.licenses.mit;
    mainProgram = "mcpjungle";
  };
}
