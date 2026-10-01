{ ... }:

# User tools live in mise; Nix retains the activation handoff until migrated.
{
  imports = [ ../features/common.nix ];
}
