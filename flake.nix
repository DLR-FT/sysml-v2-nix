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
          };

          # long live the legacy...
          # 2023-11-13: jdk17 breaks
          java = pkgs.jdk11_headless;
          sbt = pkgs.sbt.override { jre = java; };

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
              depsSha256 = "sha256-3N+P965gG3QfZ8ygnFaGf1TXOcNU3RfPmxvga//4c5E=";

              # inspired from https://github.com/sbt/sbt/issues/6541#issuecomment-860213415
              postPatch = ''
                echo 'addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.1.4")' >> project/plugins.sbt
              '';
              overrideDepsAttrs = final: prev: { inherit postPatch; };


              buildPhase = ''
                runHook preInstall

                sbt compile

                runHook postInstall
              '';


              installPhase = ''
                runHook preInstall

                sbt assembly
                cp --archive --recursive -- . $out

                runHook postInstall
              '';
            };
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [ java sbt ];
          };
        }
      );
}
