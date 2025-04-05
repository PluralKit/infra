{ stdenv
, lib
, python3
, postgresql_15
, wal-g
, makeWrapper
}:

let
  deps = [
    python3
    postgresql_15
    wal-g
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
    cp ${./walg.sh} $out/bin/pk-walg && chmod +x $out/bin/pk-walg

    for fn in $out/bin/*
    do
      wrapProgram $fn --set PATH ${lib.makeBinPath deps}
    done
  '';
}
