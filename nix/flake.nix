{
  description = "codethread's system configuration — macOS (nix-darwin) + NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";

    todoist-src = {
      url = "github:codethread/todoist/codethread";
      flake = false;
    };

    playwright-cli-src = {
      url = "github:microsoft/playwright-cli";
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

  outputs = { self, nixpkgs, nixpkgs-master, codex-cli-nix, todoist-src, playwright-cli-src, nix-darwin, home-manager, ... }:
  let
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

    playwrightCliOverlay = final: prev: {
      playwright-cli = final.buildNpmPackage {
        pname = "playwright-cli";
        version = "0-unstable";
        src = playwright-cli-src;
        npmDepsHash = "sha256-D5FNPMXc4+MgNYwxfZTn5i7DUH1erlPi8m3WOVZbVfg=";
        dontNpmBuild = true;
        env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      };
    };

    # Each host picks a profile from nix/profiles/ and binds it to one user.
    hmFor = username: profile: pkgsMaster: codexCliPackage: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { inherit pkgsMaster codexCliPackage; };
      home-manager.users = {
        "${username}" = import profile;
      };
    };

    darwinFor = hostModule: username: profile: nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin"; # Intel Mac: x86_64-darwin
      specialArgs = { pkgsMaster = pkgsMasterFor "aarch64-darwin"; };
      modules = [
        { nixpkgs.overlays = [ todoistOverlay playwrightCliOverlay ]; }
        hostModule
        home-manager.darwinModules.home-manager
        (hmFor
          username
          profile
          (pkgsMasterFor "aarch64-darwin")
          codex-cli-nix.packages.aarch64-darwin.default)
      ];
    };

    pkgsMasterFor = system: import nixpkgs-master {
      inherit system;
      config.allowUnfree = true;
      config.allowUnsupportedSystem = true;
    };
  in {
    # macOS (personal) — darwin-rebuild switch --flake .#home
    # Hostname must match: scutil --get LocalHostName
    darwinConfigurations.home = darwinFor
      ./hosts/darwin/home
      "codethread"
      ./profiles/personal.nix;

    # macOS (work, dotted username) — darwin-rebuild switch --flake .#work
    darwinConfigurations.work = darwinFor
      ./hosts/darwin/work
      "adam.hall"
      ./profiles/work.nix;

    # macOS (work, short username) — darwin-rebuild switch --flake .#work-adamhall
    darwinConfigurations.work-adamhall = darwinFor
      ./hosts/darwin/work-adamhall
      "adamhall"
      ./profiles/work.nix;

    # NixOS (homelab profile, Intel) — sudo nixos-rebuild switch --flake .#homelab
    nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { pkgsMaster = pkgsMasterFor "x86_64-linux"; };
      modules = [
        { nixpkgs.overlays = [ todoistOverlay playwrightCliOverlay ]; }
        ./hosts/nixos/homelab
        home-manager.nixosModules.home-manager
        (hmFor
          "codethread"
          ./profiles/homelab.nix
          (pkgsMasterFor "x86_64-linux")
          codex-cli-nix.packages.x86_64-linux.default)
      ];
    };

    # NixOS (VM on Apple Silicon) — sudo nixos-rebuild switch --flake .#vm
    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { pkgsMaster = pkgsMasterFor "aarch64-linux"; };
      modules = [
        { nixpkgs.overlays = [ todoistOverlay playwrightCliOverlay ]; }
        ./hosts/nixos/vm-aarch
        home-manager.nixosModules.home-manager
        (hmFor
          "codethread"
          ./profiles/vm.nix
          (pkgsMasterFor "aarch64-linux")
          codex-cli-nix.packages.aarch64-linux.default)
      ];
    };
  };
}
