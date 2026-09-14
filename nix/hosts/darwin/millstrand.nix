{ ... }:

{
  imports = [ ./dev-tools.nix ];

  homebrew.taps = [
    {
      name = "codethread/millstrand";
      clone_target = "https://github.com/codethread/millstrand";
      trusted = true;
    }
  ];

  homebrew.brews = [
    "codethread/millstrand/millstrand"
  ];
}
