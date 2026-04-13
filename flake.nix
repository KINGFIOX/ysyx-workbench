{
  description = "YSYX (one student one chip) develop environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    espresso.url = "github:KINGFIOX/espresso";
    fixdep.url = "github:KINGFIOX/fixdep";
    nvboard = {
      url = "github:KINGFIOX/nvboard";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spike = {
      url = "github:KINGFIOX/riscv-isa-sim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      espresso,
      fixdep,
      nvboard,
      spike,
    }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (import ./nix/overlay.nix)
          ];
        };


        buildTools = with pkgs; [
          gnumake
          cmake
          ninja
          pkg-config
          autoconf
          automake
        ];

        cppToolchain = with pkgs; [
          clang
          clang-tools
          gdb
          lldb
          bear
          scons
        ];

        chiselDeps = with pkgs; [
          jdk21
          circt
          metals
          scalafix
          mill_0_12_4
        ];

        verilogTools = with pkgs; [
          verilator
          iverilog
          surfer
        ];

        sdlDeps = with pkgs; [
          SDL2
          SDL2_image
          SDL2_ttf
          ffmpeg
        ];

        nemuDeps = with pkgs; [
          abseil-cpp
        ];

        npcDeps = with pkgs; [
          spike.packages.${system}.default
          nvboard.packages.${system}.default
          flex
          bison
          readline
          elfio
          zlib
        ];

        riscvToolchain = [
          pkgs.pkgsCross.riscv64-embedded.buildPackages.gcc
        ];

        pythonTools = with pkgs; [
          python3
          ruff
        ];

        miscTools = with pkgs; [
          git
          ccache
        ];

        externalPkgs = [
          espresso.packages.${system}.default
          fixdep.packages.${system}.default
        ];

      in
      {
        devShells.default = pkgs.mkShell {
          name = "ysyx-dev";

          packages = pkgs.lib.concatLists [
            buildTools
            cppToolchain
            nemuDeps
            chiselDeps
            npcDeps
            verilogTools
            sdlDeps
            riscvToolchain
            pythonTools
            miscTools
            externalPkgs
          ];

          # mkShell would export the same name of env var to shell
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          VERILATOR_ROOT = "${pkgs.verilator}/share/verilator";
          JAVA_HOME = pkgs.jdk21;
          CHISEL_FIRTOOL_PATH = "${pkgs.circt}/bin";
          SDL2_CONFIG = "${pkgs.SDL2}/bin/sdl2-config";
          CROSS_COMPILE = "riscv64-none-elf-";
          ARCH = "riscv64-npc";

          shellHook = ''
            export CC=clang
            export CXX=clang++

            export YSYX_HOME="$(pwd)"
            export NEMU_HOME="$YSYX_HOME/nemu"
            export AM_HOME="$YSYX_HOME/abstract-machine"
            export NPC_HOME="$YSYX_HOME/npc"
            export XV6_HOME="$YSYX_HOME/xv6"

            echo "🚀 YSYX develop environment loaded!"
            echo "   NEMU_HOME:    $NEMU_HOME"
            echo "   AM_HOME:      $AM_HOME"
            echo "   NPC_HOME:     $NPC_HOME"
          '';
        };
      }
    );
}
