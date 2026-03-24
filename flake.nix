{
  description = "YSYX (一生一芯) 开发环境";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    espresso.url = "github:KINGFIOX/espresso";
    fixdep.url = "github:KINGFIOX/fixdep";
    nvboard.url = "github:KINGFIOX/nvboard";
    spike.url = "github:KINGFIOX/riscv-isa-sim";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
      espresso,
      fixdep,
      nvboard,
      spike,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (import ./nix/overlay.nix)
            rust-overlay.overlays.default
          ];
        };

        inherit (pkgs) lib;

        stubsIlp32Fix = pkgs.writeTextDir "include/gnu/stubs-ilp32.h"
          "/* Empty stub for rv32 ilp32 ABI compatibility */";

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

        nemuDeps = with pkgs; [
          flex
          bison
          readline
          ncurses
          llvmPackages.libllvm
          libelf
          capstone
          kconfig-frontends
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
          gtkwave
        ];

        # sdl2-compat (SDL3 backend) 与 gcc-11.4.0 的 glibc 版本不兼容，
        # 使用旧版原生 SDL2
        sdlDeps = with pkgs; [
          SDL2
          SDL2_image
          SDL2_ttf
          ffmpeg
        ];

        riscvToolchain = [
          pkgs.pkgsCross.riscv32.buildPackages.gcc
          stubsIlp32Fix
        ];

        rustToolchain = [
          (pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" ];
          })
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

          packages = lib.concatLists [
            buildTools
            cppToolchain
            nemuDeps
            chiselDeps
            verilogTools
            sdlDeps
            riscvToolchain
            rustToolchain
            pythonTools
            miscTools
            externalPkgs
          ];

          # mkShell 会将这些属性自动导出为同名环境变量
          STUBS_ILP32_FIX = "${stubsIlp32Fix}/include";
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          VERILATOR_ROOT = "${pkgs.verilator}/share/verilator";
          NVBOARD_HOME = nvboard.packages.${system}.default;
          SPIKE_HOME = spike.packages.${system}.default;
          JAVA_HOME = pkgs.jdk21;
          CHISEL_FIRTOOL_PATH = "${pkgs.circt}/bin";
          SDL2_CONFIG = "${pkgs.SDL2}/bin/sdl2-config";
          CROSS_COMPILE = "riscv32-unknown-linux-gnu-";
          ARCH = "riscv32-npc";

          shellHook = ''
            export CC=clang
            export CXX=clang++

            export YSYX_HOME="$(pwd)"
            export NEMU_HOME="$YSYX_HOME/nemu"
            export AM_HOME="$YSYX_HOME/abstract-machine"
            export NPC_HOME="$YSYX_HOME/npc"

            export CARGO_HOME="$NPC_HOME/.cargo"
            export PATH="$CARGO_HOME/bin:$PATH"

            echo "🚀 YSYX 开发环境已加载!"
            echo "   NEMU_HOME:    $NEMU_HOME"
            echo "   AM_HOME:      $AM_HOME"
            echo "   NPC_HOME:     $NPC_HOME"
            echo "   NVBOARD_HOME: $NVBOARD_HOME"
            echo "   SPIKE_HOME:   $SPIKE_HOME"
          '';
        };
      }
    );
}
