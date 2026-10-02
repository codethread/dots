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
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      ...
    }:
    let
      darwinUser = username: { ... }: {
        system.primaryUser = username;
        users.users.${username} = {
          home = "/Users/${username}";
          shell = "/bin/zsh";
        };
      };

      darwinFor =
        hostModule: username:
        nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin"; # Intel Mac: x86_64-darwin
          modules = [
            (darwinUser username)
            hostModule
          ];
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
      darwinConfigurations.dev = darwinFor ./hosts/darwin/dev.nix "ct";

      # macOS (personal laptop) — darwin-rebuild switch --flake .#personal
      darwinConfigurations.personal = darwinFor ./hosts/darwin/personal.nix "codethread";

      # macOS (work boot, dotted username) — darwin-rebuild switch --flake .#work-boot
      darwinConfigurations.work-boot = darwinFor (import ./hosts/darwin/work.nix {
        boot = true;
      }) "adam.hall";

      # macOS (work boot, short username) — darwin-rebuild switch --flake .#work-adamhall-boot
      darwinConfigurations.work-adamhall-boot = darwinFor (import ./hosts/darwin/work.nix {
        boot = true;
      }) "adamhall";

      # macOS (full work, current username) — darwin-rebuild switch --flake .#work
      darwinConfigurations.work = darwinFor (import ./hosts/darwin/work.nix { }) "adamhall";
    };
}
