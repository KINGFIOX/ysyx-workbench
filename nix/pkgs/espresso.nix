# 仅使用本地源码 nix/pkgs/espresso（overlay 传入 src）
{ stdenv, cmake, ninja, src }:
stdenv.mkDerivation {
  pname = "espresso";
  version = "2.4";
  nativeBuildInputs = [ cmake ninja ];
  inherit src;
}
