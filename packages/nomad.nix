{ stdenv, fetchurl, ... }:

stdenv.mkDerivation rec {
	name = "nomad";
	version = "1.9.3";
	src = fetchurl {
		url = "https://packages.pluralkit.net/nomad/48009622145523e405b16a9d40722e39b48822f6/package.tar.gz";
		hash = "sha256-MI13iwVse7BgTMq9aYR4KMJTJ4FJs8e9dZ+oXWs9QiQ=";
	};

	installPhase = ''
		install -D nomad $out/bin/nomad
	'';

  dontConfigure = true;
  dontBuild = true;
	dontStrip = true;
	dontPatchELF = true;
}
