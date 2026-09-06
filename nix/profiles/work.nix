{ pkgs, ... }:

# Work profile: common packages + work infra/cloud tools.
# Used by: darwinConfigurations.work

{
  imports = [
    ../features/common.nix
  ];

  ct.claude-code.workMachine = true;

  home.packages = with pkgs; [
    # --- AWS / infra ---
    awscli2
    buf
    vault
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
