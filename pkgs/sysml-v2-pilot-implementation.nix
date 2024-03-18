{ lib, fetchFromGitHub, makeWrapper, gradle, maven, openjdk11_headless, yarn }:

let
  java = openjdk11_headless;
  mavenWithCustomJava = maven.override {
    jdk = java;
  };
in

mavenWithCustomJava.buildMavenPackage rec {
  # pname = "plantuml-sysml-v2";
  pname = "sysml-v2-pilot-implementation";
  version = "2023-11";

  src = fetchFromGitHub {
    owner = "Systems-Modeling";
    repo = "SysML-v2-Pilot-Implementation";
    rev = version;
    hash = "sha256-6bEAXVAxLbISEVtKQ05H9P2dgx8/Zc18gpFzSy4jaEU=";
  };

  # the repo contains a couple of shell scripts which need to be executable in order for the depency
  # fetching to work, for example `org.omg.sysml.jupyter.kernel/gradlew`
  #
  # Some of the jupyter stuff calls on yarn to fetch some npm packages
  mvnFetchExtraArgs = { inherit postPatch; };
  postPatch = ''
    patchShebangs .
    sed '/jupyter/d' --in-place pom.xml
  '';

  mvnHash = "sha256-PBQwnnzKQR/2IAu32Z9kwBsfDUox6z8lBbYaUClkxqk=";

  nativeBuildInputs = [ makeWrapper java ];

  installPhase = ''
    runHook preInstall
    mkdir --parent -- $out/bin '$out/share/${pname}/'
    find result/ -maxdepth 3 -wholename '*/target/*.jar' -exec \
      install -Dm644 {} '$out/share/${pname}/' \;
    cp -- target/generated-docs/*.pdf $out/docs
    runHook postInstall
  '';

  meta = with lib; {
    description = "Prototyp SysML v2 implementations";
    homepage = "https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation";
    # license = with licesens; [ gpl3 lgpl3 ]; # readme only claims lgpl3
    maintainers = with maintainers; [ wucke13 ];
  };
}
