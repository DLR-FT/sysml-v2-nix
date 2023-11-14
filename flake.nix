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
              depsSha256 = "sha256-jrVNSSXTj+4mZeRrqPiLvXxUoj58OFhqIJhukcfNyvk=";

              # Per default, sbt builds a thin jar, which does not contain all its dependencies. The
              # sbt-assembly plugin allows the building of fat lib, that contains all dependencies.
              # Unfortunately, some of the dependencies clash, thus it is necessary to merge specify
              # a dismissive merge strategy.
              #
              # inspired from https://github.com/sbt/sbt/issues/6541#issuecomment-860213415
              # and https://stackoverflow.com/a/39058507
              postPatch = ''
                cat << EOF >> project/plugins.sbt
                addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.1.4")
                EOF

                cat << EOF >> build.sbt
                assemblyMergeStrategy in assembly := {
                  case PathList("META-INF", _*) => MergeStrategy.discard
                  case _                        => MergeStrategy.first
                }
                EOF
              '';
              overrideDepsAttrs = final: prev: { inherit postPatch; };


              buildPhase = ''
                runHook preInstall

                sbt compile

                runHook postInstall
              '';


              installPhase = ''
                runHook preInstall

                sbt package
                sbt assembly
                sbt 'inspect run' 'show runtime:fullClasspath'
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
