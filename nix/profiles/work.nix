{ pkgs, ... }:

# Work profile: common packages + work infra/cloud tools.
# Used by: darwinConfigurations.work

{
  imports = [
    ../features/common.nix
    ../features/darwin-common.nix
  ];

  home.packages = with pkgs; [
    # --- AWS / infra ---
    awscli2
    buf
    vault
    podman
    podman-compose
    miller

    # --- APIs / gRPC ---
    grpcui
    grpcurl

    # --- Git forges ---
    glab

    # --- Rust / Lambda ---
    cargo-lambda

    # TODO: verify/add overlays for packages not yet in nixpkgs:
    #   vault-token-helper — third-party, may need overlay
  ];
}
