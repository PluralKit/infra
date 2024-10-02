{ stdenv
, lib
, python3
, postgresql_15
, makeWrapper
}:

let
  deps = [
    python3
    postgresql_15
  ];

in
stdenv.mkDerivation rec {
  pname = "pluralkit-scripts";
  version = "1";

  buildInputs = [ makeWrapper ] ++ deps;

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out/bin
    cp ${./messagedump.py} $out/bin/pk-messagedump && chmod +x $out/bin/pk-messagedump
    cp ${./dispatchtest.py} $out/bin/pk-dispatchtest && chmod +x $out/bin/pk-dispatchtest

    for fn in $out/bin/*
    do
      wrapProgram $fn --set PATH ${lib.makeBinPath deps}
    done
  '';
}
