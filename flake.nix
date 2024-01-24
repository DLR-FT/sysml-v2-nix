{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.sbt.url = "github:zaninime/sbt-derivation";
  inputs.sbt.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages = rec {
          default = sysml-v2-api-server;

          sysml-v2-api-server = pkgs.callPackage pkgs/sysml-v2-api-services.nix {
            mkSbtDerivation = inputs.sbt.mkSbtDerivation.${system};
          };
        };
      });
}
