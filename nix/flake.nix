{
  description = "codethread's system configuration — macOS (nix-darwin) + NixOS";

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

    tree-sitter-jsonc-src = {
      url = "github:lymansix/tree-sitter-jsonc";
      flake = false;
    };

    todoist-src = {
      url = "github:codethread/todoist/codethread";
      flake = false;
    };

    pi-btw-src = {
      url = "github:dbachelder/pi-btw/v0.4.1";
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
      tree-sitter-jsonc-src,
      todoist-src,
      pi-btw-src,
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

      nvimTreesitterJsoncOverlay = final: prev: {
        vimPlugins = prev.vimPlugins.extend (
          self: super:
          if (super.nvim-treesitter.parsers or { }) ? jsonc then
            { }
          else
            let
              jsoncParser = final.tree-sitter.buildGrammar {
                language = "jsonc";
                version = "0-unstable";
                src = tree-sitter-jsonc-src;
                meta.homepage = "https://github.com/lymansix/tree-sitter-jsonc";
              };

              jsoncPlugin = final.neovimUtils.grammarToPlugin jsoncParser;

              builtGrammars = super.nvim-treesitter.builtGrammars // {
                jsonc = jsoncParser;
                "tree-sitter-jsonc" = jsoncParser;
              };

              grammarPlugins = super.nvim-treesitter.grammarPlugins // {
                jsonc = jsoncPlugin;
              };

              allGrammars = super.nvim-treesitter.allGrammars ++ [ jsoncParser ];

              withPlugins =
                f:
                let
                  selectedGrammars = f (final.tree-sitter.builtGrammars // builtGrammars);
                  grammarPlugins' = map final.neovimUtils.grammarToPlugin selectedGrammars;
                  queryPlugins = final.lib.pipe selectedGrammars [
                    (map (grammar: grammar.associatedQuery or null))
                    (final.lib.filter (query: query != null))
                  ];
                in
                self.nvim-treesitter.overrideAttrs {
                  passthru.dependencies = grammarPlugins' ++ queryPlugins;
                };
            in
            {
              nvim-treesitter = super.nvim-treesitter.overrideAttrs (old: {
                passthru = (old.passthru or { }) // {
                  parsers = (super.nvim-treesitter.parsers or { }) // {
                    jsonc = jsoncPlugin;
                  };
                  inherit
                    builtGrammars
                    grammarPlugins
                    allGrammars
                    withPlugins
                    ;
                  withAllGrammars = withPlugins (_: allGrammars);
                };
              });
            }
        );
      };

      # Each host picks a profile from nix/profiles/ and binds it to one user.
      hmFor = username: profile: pkgsMaster: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit pkgsMaster pi-btw-src;
        };
        home-manager.users = {
          "${username}" = import profile;
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
                nvimTreesitterJsoncOverlay
              ];
            }
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
            nvimTreesitterJsoncOverlay
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
        darwinFor ./hosts/darwin/work-adamhall-boot.nix "adamhall"
          ./profiles/work-boot.nix;

      # macOS (full work, current username) — darwin-rebuild switch --flake .#work
      darwinConfigurations.work =
        darwinFor ./hosts/darwin/work-adamhall.nix "adamhall"
          ./profiles/work.nix;

      # NixOS (homelab profile, Intel) — sudo nixos-rebuild switch --flake .#homelab
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          pkgsMaster = pkgsMasterFor "x86_64-linux";
        };
        modules = [
          {
            nixpkgs.overlays = [
              llmAgentsOverlay
              nufmtOverlay
              todoistOverlay
              nvimTreesitterJsoncOverlay
            ];
          }
          ./hosts/nixos/homelab
          home-manager.nixosModules.home-manager
          (hmFor "codethread" ./profiles/homelab.nix (pkgsMasterFor "x86_64-linux"))
        ];
      };

      # NixOS (VM on Apple Silicon) — sudo nixos-rebuild switch --flake .#vm
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          pkgsMaster = pkgsMasterFor "aarch64-linux";
        };
        modules = [
          {
            nixpkgs.overlays = [
              llmAgentsOverlay
              nufmtOverlay
              todoistOverlay
              nvimTreesitterJsoncOverlay
            ];
          }
          ./hosts/nixos/vm-aarch
          home-manager.nixosModules.home-manager
          (hmFor "codethread" ./profiles/vm.nix (pkgsMasterFor "aarch64-linux"))
        ];
      };
    };
}
