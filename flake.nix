{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # canonical leaves so consumers below dedupe to a single node each
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kp2pml30-moe = {
      url = "github:kp2pml30/kp2pml30.github.io";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.systems.follows = "systems";
      inputs.git-hooks.follows = "git-hooks";
    };

    code-flake = {
      url = "github:kp2pml30/code-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-generators,
      kp2pml30-moe,
      code-flake,
      claude-code,
      codex-cli,
      ...
    }:
    let
      rootPath = self;
      data = {
        uids = import ./nix/data/uids.nix;
        gids = import ./nix/data/gids.nix;
        ssh-keys = import ./nix/data/ssh-keys.nix;
      };
      additionalArgs = { inherit inputs rootPath data; };
      lib = nixpkgs.lib;
      forEachSystem = lib.genAttrs (import inputs.systems);
    in
    {
      nixosConfigurations = {
        vdsina = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            {
              networking.hostId = "e31a5cc1";
              time.timeZone = "Asia/Tokyo";

              kp2pml30.short-hostname = "vdsina";

              kp2pml30.server = {
                hostname = "kp2pml30.moe";
                nginx = true;
                forgejo = true;
                nix-cache = true;
                xray = true;
                headscale = true;
              };

              kp2pml30.headscale-client.enable = true;
            }

            ./nix/common.nix

            ./nix/server

            ./nix/headscale-client.nix

            ./nix/hardware/vdsina.nix

            nixos-generators.nixosModules.all-formats
          ];

          specialArgs = {
            inherit kp2pml30-moe data;
            system = "x86_64-linux";
          };
        };

        mini = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [
            ({ pkgs, ... }: {
              networking.hostName = "kp2pml30-personal-pc";
              networking.hostId = "e31a5cc2";

              time.timeZone = "Asia/Tokyo";

              nixpkgs.overlays = [
                claude-code.overlays.default
                codex-cli.overlays.default
                code-flake.overlays.default
              ];

              boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
            })

            ./nix/hardware/mini.nix

            ./nix/common.nix

            ./nix/personal

            ./nix/qemu.nix

            ./nix/xray.nix

            ./nix/headscale-client.nix

            {
              kp2pml30 = {
                short-hostname = "mini";

                xserver = true;
                vscode = true;
                kitty = true;
                opera = true;
                gayming = {
                  enable = true;
                  width = 1920;
                  height = 1080;
                  refreshRate = 60;
                };
                agent = true;
                sync-files.enable = true;
                damn-rust.enable = true;

                qemu = true;

                xray-client = true;
                xray-client-id = "mini";

                headscale-client.enable = true;

                boot.efiGrub = true;

                hardware.wireless = true;
                hardware.audio = true;

                messengers.personal = true;
                messengers.work = true;
              };
            }
          ];
          specialArgs = additionalArgs // {
            inherit system;
          };
        };
        ideapad = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [
            {
              networking.hostName = "kp2pml30-personal-laptop";
              networking.hostId = "e31a5cc0";

              nixpkgs.overlays = [ code-flake.overlays.default ];
              time.timeZone = "Asia/Tokyo";
            }

            ./nix/hardware/ideapad.nix

            ./nix/common.nix

            ./nix/personal

            ./nix/headscale-client.nix

            {
              kp2pml30 = {
                short-hostname = "ideapad";

                xserver = true;
                vscode = true;
                kitty = true;
                opera = true;
                gayming = {
                  enable = true;
                  width = 1920;
                  height = 1080;
                  refreshRate = 60;
                };
                agent = true;
                sync-files.enable = true;

                boot.efiGrub = true;

                hardware.wireless = true;
                hardware.audio = true;

                messengers.personal = true;

                headscale-client.enable = true;
                messengers.work = true;
              };
            }
          ];
          specialArgs = additionalArgs // {
            inherit system;
          };
        };

        agent-vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            { networking.hostId = "c1a0de00"; }
            ./nix/common.nix
            ./nix/agent-vm
            ./nix/personal
            ./nix/hardware/agent-vm.nix
          ];
          specialArgs = additionalArgs;
        };

        nanopi-m5 = nixpkgs.lib.nixosSystem {
          modules = [
            {
              networking.hostName = "kp2pml30-nanopi-m5";
              networking.hostId = "0fe2738b";

              time.timeZone = "Asia/Tokyo";

              nixpkgs.hostPlatform = "aarch64-linux";
            }

            ./nix/common.nix
            ./nix/server
            ./nix/hardware/nanopi-m5-homeserver
            ./nix/headscale-client.nix

            {
              kp2pml30 = {
                short-hostname = "nanopi-m5";

                headscale-client.enable = true;
              };
            }
          ];
          # nix/server submodules take these as module args even with all
          # services off.
          specialArgs = additionalArgs // {
            inherit self nixpkgs kp2pml30-moe;
            system = "aarch64-linux";
          };
        };
      };

      packages.aarch64-linux = {
        nanopi-m5-sd = self.nixosConfigurations.nanopi-m5.config.system.build.sdImage;
        nanopi-m5-toplevel = self.nixosConfigurations.nanopi-m5.config.system.build.toplevel;
      };

      formatter = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          config = self.checks.${system}.pre-commit-check.config;
          inherit (config) package configFile;
          script = ''
            ${pkgs.lib.getExe package} run --all-files --config ${configFile}
          '';
        in
        pkgs.writeShellScriptBin "pre-commit-run" script
      );

      checks = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          pre-commit-check = inputs.git-hooks.lib.${system}.run {
            src = ./.;
            excludes = [ "\.lock$" ];
            hooks = {
              check-commit-message = {
                enable = true;
                name = "check commit message";
                description = "Validate the commit message against conventional-commit rules.";
                entry = "${pkgs.python3}/bin/python3 ${./agents/skills/new-repo/example/support/scripts/check-commit-message.py} --message-file";
                language = "system";
                stages = [ "commit-msg" ];
              };

              trim-trailing-whitespace.enable = true;
              end-of-file-fixer.enable = true;
              detect-private-keys.enable = true;

              nixfmt.enable = true;
              ruff.enable = true;
              ruff-format.enable = true;
              taplo.enable = true;
              stylua.enable = true;
              editorconfig-checker.enable = true;
            };
          };
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
        in
        {
          default = pkgs.mkShell {
            inherit shellHook;
            buildInputs = enabledPackages;
          };
        }
      );
    };
}
