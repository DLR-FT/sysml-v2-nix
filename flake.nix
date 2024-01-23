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
          # 2023-11-13: jdk17 breaks, the upstream projects requires Java 11
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
            default = sysml-v2-api-server;
            sysml-v2-api-server = mkSbtDerivation rec {
              pname = "SysML-v2-API-Services";
              version = "2023-02";
              src = pkgs.fetchFromGitHub {
                owner = "Systems-Modeling";
                repo = pname;
                rev = version;
                sha256 = "sha256-kel3zWaIUE7AtiXQMuQ4nYJ9ln892XlukDOp5MOLg3c=";
              };
              depsSha256 = "sha256-3N+P965gG3QfZ8ygnFaGf1TXOcNU3RfPmxvgZ//4c5E=";

              patches = [
                ./emf-use-system-properties.patch
              ];

              # remove hardcoded, un-overridable Database credentials
              # more info:
              # https://stackoverflow.com/a/17594064
              postPatch = ''
                sed '/javax\.persistence\.jdbc/d' --in-place conf/META-INF/persistence.xml
              '';

              buildPhase = ''
                runHook preBuild
                sbt dist
                runHook postBuild
              '';

              installPhase = ''
                runHook preInstall
                unzip target/universal/*.zip
                mv sysml-* $out
                runHook postInstall
              '';
              preFixup = ''
                wrapProgram $out/bin/sysml-v2-api-services \
                  --suffix PATH : ${pkgs.lib.makeBinPath (with pkgs; [ gawk java ])}
              '';
              nativeBuildInputs = with pkgs; [
                makeWrapper
                unzip
              ];
              meta.mainProgram = "sysml-v2-api-services";
            };
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              java
              pkgs.postgresql
              sbt
            ];
          };
        });
}
