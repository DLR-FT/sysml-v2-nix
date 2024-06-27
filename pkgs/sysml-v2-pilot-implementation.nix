{ lib, fetchFromGitHub, makeWrapper, gradle, maven, openjdk17_headless, yarn }:

let
  java = openjdk17_headless;
  mavenWithCustomJava = maven.override {
    jdk = java;
  };
in

mavenWithCustomJava.buildMavenPackage rec {
  # pname = "plantuml-sysml-v2";
  pname = "sysml-v2-pilot-implementation";
  version = "2024-05";

  src = fetchFromGitHub {
    owner = "Systems-Modeling";
    repo = "SysML-v2-Pilot-Implementation";
    rev = version;
    hash = "sha256-rPGJkFRXE4ZEf52lB4sXVWIXlpFf+dLRECQl0tWYo7A=";
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

  mvnHash = "sha256-6t4ClxfMCcaqFnR/Dkgd+884aJuV+Oc9sxYHL3twP9Y=";

  nativeBuildInputs = [ makeWrapper java ];

  installPhase = ''
    runHook preInstall

    # crate target dir
    mkdir --parent -- $out/bin $out/docs/ $out/share/${pname} 

    # copy all interesting JAR files
    find . -maxdepth 3 -wholename '*/target/*.jar' -exec \
      install -Dm644 {} $out/share/${pname}/ \;

    # wrap the one main executable
    makeWrapper ${lib.meta.getExe java} $out/bin/sysml-interactive --add-flags "-jar $out/share/sysml-v2-pilot-implementation/org.omg.sysml.interactive-*-SNAPSHOT-all.jar"

    # copy the manual
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
