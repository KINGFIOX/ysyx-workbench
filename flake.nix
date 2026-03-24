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

        stubsIlp32Fix = pkgs.writeTextDir "include/gnu/stubs-ilp32.h"
          "/* Empty stub for rv32 ilp32 ABI compatibility */";

        # ccache masquerade: 用编译器同名符号链接指向 ccache，透明加速编译
        ccacheLinks = pkgs.runCommand "ccache-links" { } ''
          mkdir -p $out/bin
          for prog in gcc g++ cc c++ \
                      riscv32-unknown-linux-gnu-gcc riscv32-unknown-linux-gnu-g++; do
            ln -s ${pkgs.ccache}/bin/ccache $out/bin/$prog
          done
        '';

        # autocxx / bindgen 需要的 GCC C++ 标准库头文件路径
        gccForLibs = pkgs.gcc-unwrapped;
        gccVersion = gccForLibs.version;
        gccArch = "x86_64-unknown-linux-gnu";

      in
      {
        devShells.default = pkgs.mkShell {
          name = "ysyx-dev";

          packages = with pkgs; [
            # ========================
            # 基础构建工具
            # ========================
            gnumake
            cmake
            ninja
            cmake
            pkg-config
            autoconf
            automake

            # ========================
            # C/C++ 工具链
            # ========================
            gcc
            clang-tools
            gdb
            lldb
            bear

            # ========================
            # NEMU 依赖
            # ========================
            flex
            bison
            readline
            ncurses
            llvmPackages.libllvm
            libelf # gelf.h for ftrace
            capstone # 反汇编引擎
            kconfig-frontends # Kconfig 配置系统 (提供 kconfig-conf, kconfig-mconf)

            # ========================
            # NPC (Chisel/Scala) 依赖
            # ========================
            jdk21
            circt # 包含 firtool，Chisel 生成 Verilog 需要
            metals
            scalafix
            mill_0_12_4

            # ========================
            # Verilog/仿真工具
            # ========================
            verilator
            iverilog # Icarus Verilog
            gtkwave # 波形查看器 (可选)

            # ========================
            # NVBoard / 图形界面依赖
            # ========================
            # 使用旧版 SDL2（原生），而不是 nixpkgs-unstable 的 sdl2-compat（需要 SDL3）
            # sdl2-compat 与 gcc-11.4.0 的 glibc 版本不兼容
            SDL2
            SDL2_image
            SDL2_ttf
            ffmpeg

            # ========================
            # RISC-V 交叉编译工具链
            # ========================
            pkgsCross.riscv32.buildPackages.gcc
            stubsIlp32Fix # 修复缺少的 stubs-ilp32.h

            # ========================
            # Rust 工具链 (via rust-overlay)
            # ========================
            (rust-bin.stable.latest.default.override {
              extensions = [ "rust-src" "rust-analyzer" ];
            })

            # ========================
            # Python 工具链
            # ========================
            python3
            ruff # lsp of python

            # ========================
            # 实用工具
            # ========================
            git
            bear # 生成 compile_commands.json
            ccache # CLI 工具 (ccache -s 查看统计等)
          ] ++ [
            espresso.packages.${system}.default
            fixdep.packages.${system}.default
          ];

          # 环境变量设置
          STUBS_ILP32_FIX = "${stubsIlp32Fix}/include";

          # autocxx / bindgen: libclang 路径
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

          # Verilator: include 路径 (供 build.rs 使用)
          VERILATOR_ROOT = "${pkgs.verilator}/share/verilator";

          # autocxx / bindgen: GCC C++ 标准库头文件路径
          BINDGEN_EXTRA_CLANG_ARGS = builtins.toString [
            "-isystem${gccForLibs}/include/c++/${gccVersion}"
            "-isystem${gccForLibs}/include/c++/${gccVersion}/${gccArch}"
            "-isystem${gccForLibs}/lib/gcc/${gccArch}/${gccVersion}/include"
            "-isystem${gccForLibs}/lib/gcc/${gccArch}/${gccVersion}/include-fixed"
            "-isystem${pkgs.glibc.dev}/include"
          ];

          shellHook = ''
            # 设置项目根目录
            export YSYX_HOME="$(pwd)"
            export CCACHE_DIR="$YSYX_HOME/.ccache"
            export NEMU_HOME="$YSYX_HOME/nemu"
            export AM_HOME="$YSYX_HOME/abstract-machine"
            export NPC_HOME="$YSYX_HOME/npc"
            export NVBOARD_HOME="${nvboard.packages.${system}.default}"
            export SPIKE_HOME="${spike.packages.${system}.default}"

            # ccache 加速：将 masquerade 目录放在 PATH 最前面
            export PATH="${ccacheLinks}/bin:$PATH"

            export CC=gcc
            export CXX=g++

            # RISC-V 交叉编译工具链
            export CROSS_COMPILE=riscv32-unknown-linux-gnu-

            # Java 设置 (for Bazel/Scala)
            export JAVA_HOME="${pkgs.jdk21}"

            # Chisel/CIRCT: 使用系统的 firtool
            export CHISEL_FIRTOOL_PATH="${pkgs.circt}/bin"

            # SDL2 配置 (使用旧版 SDL2)
            export SDL2_CONFIG="${pkgs.SDL2}/bin/sdl2-config"

            # Rust/Cargo: 避免污染家目录
            export CARGO_HOME="$NPC_HOME/.cargo"
            export PATH="$CARGO_HOME:$PATH"

            # yosys-sta 路径
            export YOSYS_STA_HOME="$YSYX_HOME/yosys-sta"

            export ARCH=riscv32-npc

            echo "🚀 YSYX 开发环境已加载!"
            echo "   NEMU_HOME:    $NEMU_HOME"
            echo "   AM_HOME:      $AM_HOME"
            echo "   NPC_HOME:     $NPC_HOME"
            echo "   NVBOARD_HOME: $NVBOARD_HOME"
            echo "   SPIKE_HOME: $SPIKE_HOME"
            echo "   YOSYS_STA_HOME: $YOSYS_STA_HOME"
            echo ""
            echo "📦 可用工具: gcc, verilator, gdb, iverilog..."
            echo "🔧 RISC-V 工具链: $CROSS_COMPILE"
          '';

          # 确保 C/C++ 编译器能找到头文件和库
          hardeningDisable = [ "all" ];
        };
      }
    );
}
