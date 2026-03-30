{
  description = "Oven development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
  let
    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    devShells = forEachSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            biome
            typescript
          ];

          BIOME_BINARY = "${pkgs.biome}/bin/biome";
        };
      });
  };
}
