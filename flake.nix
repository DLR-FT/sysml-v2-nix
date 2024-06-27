{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.sbt.url = "github:zaninime/sbt-derivation";
  inputs.sbt.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    {
      nixosModules.default = import ./module.nix self;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages = {
          sys-ide-lsp-bin = pkgs.callPackage pkgs/sys-ide-lsp-bin.nix { };
          sys-ide-vscode-bin = pkgs.callPackage pkgs/sys-ide-vscode-bin.nix { };

          sysml-v2-pilot-implementation = pkgs.callPackage pkgs/sysml-v2-pilot-implementation.nix { };

          sysml-v2-api-server = pkgs.callPackage pkgs/sysml-v2-api-services.nix {
            mkSbtDerivation = inputs.sbt.mkSbtDerivation.${system};
          };

          syson-web = pkgs.callPackage pkgs/syson-web.nix { };
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            nixpkgs-fmt
          ];
        };

        checks.nixpkgs-fmt = pkgs.runCommand "nixpkgs-fmt"
          {
            nativeBuildInputs = [ pkgs.nixpkgs-fmt ];
          } "nixpkgs-fmt --check ${./.}; touch $out";

        hydraJobs = (nixpkgs.lib.filterAttrs (n: _: n != "default") self.packages.${system}) // self.checks.${system};
      });
}
