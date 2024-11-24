{ stdenv
, lib
, coreutils
, jq
, iproute2
, makeWrapper
}:

let
  deps = [
    coreutils
    jq
    iproute2
  ];

in
stdenv.mkDerivation rec {
  pname = "check-interface-ready";
  version = "1";

  buildInputs = [ makeWrapper ] ++ deps;

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out/bin
    cp ${./check-interface-ready.sh} $out/bin/check-interface-ready && chmod +x $out/bin/check-interface-ready

    for fn in $out/bin/*
    do
      wrapProgram $fn --set PATH ${lib.makeBinPath deps}
    done
  '';
}
