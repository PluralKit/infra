{ stdenv, fetchurl, ... }:

stdenv.mkDerivation rec {
	name = "caddy";
	version = "2.8.4";
	src = fetchurl {
		url = "https://packages.pluralkit.net/caddy/7cea09489894ad092c59d2c99f2b16a73e052397/package.tar.gz";
		hash = "sha256-OYHYUAfD567xSZ3cEpp5hUZ8pWmDFabx00QgD2pJehI=";
	};

	installPhase = ''
		install -D caddy $out/bin/caddy
	'';

  dontConfigure = true;
  dontBuild = true;
	dontStrip = true;
	dontPatchELF = true;
}
