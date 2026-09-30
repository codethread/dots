{
  description = "codethread's system configuration — macOS (nix-darwin)";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    nufmt.url = "github:nushell/nufmt";

    todoist-src = {
      url = "github:codethread/todoist/codethread";
      flake = false;
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-master,
      llm-agents,
      nufmt,
      todoist-src,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      llmAgentsOverlay = final: prev: {
        "llm-agents" = llm-agents.packages.${final.system};
      };
      nufmtOverlay = final: prev: {
        nufmt = nufmt.packages.${final.system}.default;
      };

      todoistOverlay = final: prev: {
        todoist-cli = final.buildGoModule {
          pname = "todoist";
          version = "0-unstable";
          src = todoist-src;
          vendorHash = "sha256-eVB5k/Z5Z6SsPqySPm4xZIh07c9xbijImRk8zdvY6tA=";
          nativeBuildInputs = [ final.gotools ];
          preBuild = ''
            goyacc -o filter_parser.go filter_parser.y
          '';
        };
      };

      # Each host picks a profile from nix/profiles/ and binds it to one user.
      hmFor = username: profile: pkgsMaster: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit pkgsMaster;
        };
        home-manager.users = {
          "${username}" = import profile;
        };
      };

      darwinUser = username: { pkgs, ... }: {
        system.primaryUser = username;
        users.users.${username} = {
          home = "/Users/${username}";
          shell = pkgs.zsh;
        };
      };

      darwinFor =
        hostModule: username: profile:
        nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin"; # Intel Mac: x86_64-darwin
          specialArgs = {
            pkgsMaster = pkgsMasterFor "aarch64-darwin";
          };
          modules = [
            {
              nixpkgs.overlays = [
                llmAgentsOverlay
                nufmtOverlay
                todoistOverlay
              ];
            }
            (darwinUser username)
            hostModule
            home-manager.darwinModules.home-manager
            (hmFor username profile (pkgsMasterFor "aarch64-darwin"))
          ];
        };

      pkgsMasterFor =
        system:
        import nixpkgs-master {
          inherit system;
          overlays = [
            llmAgentsOverlay
            nufmtOverlay
          ];
          config.allowUnfree = true;
          config.allowUnsupportedSystem = true;
        };
    in
    {
      devShells =
        nixpkgs.lib.genAttrs
          [
            "aarch64-darwin"
            "x86_64-darwin"
            "aarch64-linux"
            "x86_64-linux"
          ]
          (system: {
            default = nixpkgs.legacyPackages.${system}.mkShell {
              packages = [ nixpkgs.legacyPackages.${system}.nixfmt ];
            };
          });

      # macOS (personal dev machine) — darwin-rebuild switch --flake .#dev
      # Hostname must match: scutil --get LocalHostName
      darwinConfigurations.dev = darwinFor ./hosts/darwin/dev.nix "ct" ./profiles/dev.nix;

      # macOS (personal laptop) — darwin-rebuild switch --flake .#personal
      darwinConfigurations.personal =
        darwinFor ./hosts/darwin/personal.nix "codethread"
          ./profiles/personal.nix;

      # macOS (work boot, dotted username) — darwin-rebuild switch --flake .#work-boot
      darwinConfigurations.work-boot =
        darwinFor ./hosts/darwin/work-boot.nix "adam.hall"
          ./profiles/work-boot.nix;

      # macOS (work boot, short username) — darwin-rebuild switch --flake .#work-adamhall-boot
      darwinConfigurations.work-adamhall-boot =
        darwinFor ./hosts/darwin/work-boot.nix "adamhall"
          ./profiles/work-boot.nix;

      # macOS (full work, current username) — darwin-rebuild switch --flake .#work
      darwinConfigurations.work =
        darwinFor ./hosts/darwin/work-adamhall.nix "adamhall"
          ./profiles/work.nix;
    };
}
