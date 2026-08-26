{
  pkgs,
  pkgsMaster ? null,
  pi-btw-src,
  ...
}:

let
  agentPkgSet = if pkgsMaster == null then pkgs else pkgsMaster;
  pi = agentPkgSet."llm-agents".pi.override { useBun = true; };

  piNvimTarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/pi-nvim/-/pi-nvim-0.2.4.tgz";
    hash = "sha512-d03Lr+vIQp17QGrA5H9YQuv6dxKUxCQywUNVmhhsI4EGnX/aHBz9svoYtI4WRlnx2VA/BsUbjPcbJ20Q84+T0g==";
  };

  piNvim = pkgs.runCommand "pi-nvim-0.2.4" { nativeBuildInputs = [ pkgs.gnutar ]; } ''
    mkdir -p "$out"
    tar -xzf ${piNvimTarball} --strip-components=1 -C "$out"
  '';

  piBtw = pkgs.buildNpmPackage {
    pname = "pi-btw";
    version = "0.4.1";
    src = pi-btw-src;

    npmDepsHash = "sha256-iPyOl0ZJUKfutTeO4NdOuQSBVS90DU84rCWeNg8QKJQ=";
    dontNpmBuild = true;

    meta = {
      description = "A Pi extension for parallel side conversations with /btw";
      homepage = "https://github.com/dbachelder/pi-btw";
      license = pkgs.lib.licenses.mit;
    };
  };

  piMcpAdapterSrc = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-mcp-adapter";
    rev = "v2.28.0";
    hash = "sha256-NPeVITORXcJevXrBhHdiunwPiOzx+8Wzx2M03alXW2E=";
  };

  piMcpAdapterProdSrc = pkgs.runCommand "pi-mcp-adapter-2.28.0-src" { } ''
    cp -R ${piMcpAdapterSrc} "$out"
    chmod -R u+w "$out"
    ${pkgs.jq}/bin/jq 'del(.devDependencies)' \
      "$out/package.json" > "$out/package.json.tmp"
    mv "$out/package.json.tmp" "$out/package.json"

    ${pkgs.jq}/bin/jq '
      del(.packages[""].devDependencies)
      | .packages |= with_entries(select(.value.dev != true))
    ' "$out/package-lock.json" > "$out/package-lock.json.tmp"
    mv "$out/package-lock.json.tmp" "$out/package-lock.json"
  '';

  piMcpAdapter = pkgs.buildNpmPackage {
    pname = "pi-mcp-adapter";
    version = "2.28.0";
    src = piMcpAdapterProdSrc;

    npmDepsHash = "sha256-VkatFWEjFJG++Js9xkm0fR0P30F/lBENOj4YhSu0J2E=";
    npmPackFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;

    meta = {
      description = "Connect Pi to MCP servers with progressive tool discovery";
      homepage = "https://github.com/nicobailon/pi-mcp-adapter";
      license = pkgs.lib.licenses.mit;
    };
  };
in
{
  home.packages = [ pi ];

  home.file = {
    ".pi/agent/packages/pi-nvim".source = piNvim;
    ".pi/agent/packages/pi-btw".source = piBtw + "/lib/node_modules/pi-btw";
    ".pi/agent/packages/pi-mcp-adapter".source = piMcpAdapter + "/lib/node_modules/pi-mcp-adapter";
  };
}
