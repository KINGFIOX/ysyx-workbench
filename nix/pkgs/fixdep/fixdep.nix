{ stdenv }:
stdenv.mkDerivation {
  pname = "fixdep";
  version = "1.0";
  src = ./.;
  buildPhase = ''
    $CC -O2 -o fixdep fixdep.c
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp fixdep $out/bin/
  '';
}
