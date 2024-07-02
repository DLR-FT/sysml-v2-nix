{ lib, buildNpmPackage, fetchFromGitHub, nodejs_18 }:

buildNpmPackage rec {
  pname = "eclipse-syson";
  version = "2024.3.0";

  src = fetchFromGitHub {
    owner = "eclipse-syson";
    repo = "syson";
    rev = "v${version}";
    hash = "sha256-YcK566ypDqAzMXZ35Ni9NKvnfEJVr0RupvPJLaTAuBY=";
  };

  # BUG https://github.com/eclipse-syson/syson/issues/303
  npmDepsHash = "";
  # makeCacheWritable = true;
  # npmFlags = [ "--legacy-peer-deps" ];
  # npmWorkspace = "frontend/syson";

  meta.broken = true;
}
