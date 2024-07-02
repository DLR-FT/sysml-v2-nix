{ lib, stdenvNoCC, fetchurl, nodejs }:

stdenvNoCC.mkDerivation (finalAttrs: {

  pname = "syside";
  version = "0.6.0";
  src = fetchurl {
    # TODO find stable link that involves the version number
    url = "https://gitlab.com/sensmetry/public/sysml-2ls/-/jobs/6403788212/artifacts/raw/syside-languageserver.js";
    hash = "sha256-wPVPTFFl07Qu1lxVtwLmzGZ+XmMacKsuu1oIAPxqKPU=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir --parent -- $out/bin
    echo -e "#!${lib.meta.getExe nodejs}\n" > $out/bin/syside-languageserver
    cat $src >> $out/bin/syside-languageserver
    chmod +x -- $out/bin/syside-languageserver

    runHook postInstall
  '';
})
