{ ... }:

# User setup lives in mise. Retain Home Manager state for clean generation
# transitions; do not add user packages or activations here.
{
  imports = [ ../features/home-base.nix ];
}
