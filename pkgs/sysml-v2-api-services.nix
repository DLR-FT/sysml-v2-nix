{ lib, mkSbtDerivation, system, sbt, fetchFromGitHub, makeWrapper, unzip, gawk, jdk11_headless }:

let
  pname = "SysML-v2-API-Services";
  mainProgram = lib.strings.toLower pname;

  # long live the legacy...
  # 2023-11-13: jdk17 breaks, the upstream projects requires Java 11
  java = jdk11_headless;

  sbtWithCustomJava = sbt.override { jre = java; };

  # necessary because of
  # https://github.com/zaninime/sbt-derivation/issues/17
  mkSbtDerivationWithCustomJava = mkSbtDerivation.withOverrides {
    sbt = sbtWithCustomJava;
  };

in
mkSbtDerivationWithCustomJava rec {
  pname = "SysML-v2-API-Services";
  version = "2024-02";
  src = fetchFromGitHub {
    owner = "Systems-Modeling";
    repo = pname;
    rev = version;
    sha256 = "sha256-MnnLtld6UOFOYlaLVJgNbai0R8eaY8/2x/nrSbOVXO0=";
  };
  depsSha256 = "sha256-UjMEHHLalfxQOv1w0hZgFHE7KgkOJOCSCDhZpvb4ffg=";

  patches = [
    ../patches/emf-use-system-properties.patch
    ../patches/env-var-play-application-secret.patch

    # see https://jdbc.postgresql.org/documentation/use/#unix-sockets for details
    ../patches/enable-unix-domain-socket-postgres.patch
  ];

  nativeBuildInputs = [
    makeWrapper
    unzip
  ];

  # remove hardcoded, un-overridable Database credentials
  # more info:
  # https://stackoverflow.com/a/17594064
  postPatch = ''
    sed '/javax\.persistence\.jdbc/d' --in-place conf/META-INF/persistence.xml
    sed '/hibernate\.hbm2ddl\.auto/ s/create-drop/update/g' --in-place conf/META-INF/persistence.xml
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
      --suffix PATH : ${lib.makeBinPath ([ gawk java ])}
  '';
  meta = { inherit mainProgram; };
}
