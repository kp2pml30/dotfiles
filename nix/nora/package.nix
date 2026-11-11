{
  lib,
  rustPlatform,
  src,
}:
rustPlatform.buildRustPackage {
  pname = "nora";
  version = (lib.importTOML "${src}/Cargo.toml").workspace.package.version;
  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [
    "-p"
    "nora-registry"
  ];
  # Thousands of tests, many needing network or docker
  doCheck = false;
  meta.mainProgram = "nora";
}
