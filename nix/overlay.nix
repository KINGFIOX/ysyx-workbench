final: prev: {
  # fixdep: 一包一目录，包表达式在 fixdep/flake.nix，src = ./.（本地）
  # espresso 已改为 flake input (github:KINGFIOX/espresso)，见根 flake.nix
  fixdep = final.callPackage ./pkgs/fixdep/flake.nix { };

  mill_0_12_4 = prev.mill.overrideAttrs (oldAttrs: rec {
    version = "0.12.4";
    src = prev.fetchurl {
      url = "https://repo1.maven.org/maven2/com/lihaoyi/mill-dist/${version}/mill-dist-${version}-assembly.jar";
      hash = "sha256-+wSyPh2me1ud5xfkaAPhpMY8m+u+xlecYphikLKmBiE=";
    };
  });
}
