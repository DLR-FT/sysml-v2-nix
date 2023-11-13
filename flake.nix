{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.sbt.url = "github:zaninime/sbt-derivation";
  inputs.sbt.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (f: p: { jre = p.jdk17_headless; })
            ];
          };

          sbt = pkgs.sbt.override { jre = pkgs.jdk17_headless; };

          # necessary because of
          # https://github.com/zaninime/sbt-derivation/issues/17
          mkSbtDerivation = inputs.sbt.mkSbtDerivation.${system}.withOverrides
            {
              inherit sbt;
            };
        in
        {
          packages = rec {
            sysml-v2-api-server = mkSbtDerivation rec {
              pname = "SysML-v2-API-Services";
              version = "2023-02";
              src = pkgs.fetchFromGitHub {
                owner = "Systems-Modeling";
                repo = pname;
                rev = version;
                sha256 = "sha256-kel3zWaIUE7AtiXQMuQ4nYJ9ln892XlukDOp5MOLg3c=";
              };
              depsSha256 = "";
            };
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [ sbt ];
          };
        }
      );
}
