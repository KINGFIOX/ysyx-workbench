# 使用本地 clone：将 chipsalliance/espresso 克隆到 nix/pkgs/espresso 并 checkout v2.4
#   git clone https://github.com/chipsalliance/espresso.git nix/pkgs/espresso && cd nix/pkgs/espresso && git checkout v2.4
{ stdenv, cmake, ninja }:
stdenv.mkDerivation {
  pname = "espresso";
  version = "2.4";
  nativeBuildInputs = [ cmake ninja ];
  src = ./espresso;
  patches = [ ./espresso-srandom.patch ];
}
