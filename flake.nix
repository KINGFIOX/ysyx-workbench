{
  description = "YSYX (一生一芯) 开发环境";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 自 fork：meson 构建，本地开发可 override-input espresso path:/home/wangfiox/Documents/espresso
    espresso.url = "github:KINGFIOX/espresso";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
      espresso,
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

        # 创建空的 stubs-ilp32.h 来修复 rv32 编译问题
        stubsIlp32Fix = pkgs.runCommand "stubs-ilp32-fix" { } ''
          mkdir -p $out/include/gnu
          echo "/* Empty stub for rv32 ilp32 ABI compatibility */" > $out/include/gnu/stubs-ilp32.h
        '';

        # 创建 ccache 包装目录，通过 PATH prepend 方式使用 ccache
        ccacheWrapper = pkgs.runCommand "ccache-wrapper" { } ''
          mkdir -p $out/bin
          for prog in gcc g++ cc c++; do
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
            meson
            ninja
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
            dtc # spike
            capstone # 反汇编引擎
            kconfig-frontends # Kconfig 配置系统 (提供 kconfig-conf, kconfig-mconf)
            fixdep # 依赖优化工具

            # ========================
            # NPC (Chisel/Scala) 依赖
            # ========================
            jdk21
            scala_2_13
            circt # 包含 firtool，Chisel 生成 Verilog 需要
            metals # mill 不会自动下载
            mill_0_12_4 # 锁定到 0.12.4 版本
            scalafix

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
            SDL2_mixer # 可能需要音频支持
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
            # 实用工具
            # ========================
            git
            python3
            ruff # lsp of python
            bear # 生成 compile_commands.json
            ccache
          ] ++ [
            espresso.packages.${system}.default # QMC 逻辑最小化 (Chisel DecodeTable)，自 fork meson 构建
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
            export NEMU_HOME="$YSYX_HOME/nemu"
            export AM_HOME="$YSYX_HOME/abstract-machine"
            export NPC_HOME="$YSYX_HOME/npc"
            export NVBOARD_HOME="$YSYX_HOME/nvboard"
            export SPIKE_HOME="$YSYX_HOME/tools/spike"

            # 使用 ccache: 通过 PATH prepend 方式，让 gcc/g++ 调用自动走 ccache
            export PATH="${ccacheWrapper}/bin:$PATH"

            # 主机编译器 (确保 CC/CXX 是主机工具链)
            export CC=gcc
            export CXX=g++

            # RISC-V 交叉编译工具链
            export CROSS_COMPILE=riscv32-unknown-linux-gnu-

            # Java 设置 (for Mill/Scala)
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

            # GDB 自动加载安全路径配置
            # 确保 GDB 可以自动加载项目中的 .gdbinit 文件
            mkdir -p "$HOME/.config/gdb"
            if ! grep -q "add-auto-load-safe-path.*$YSYX_HOME" "$HOME/.config/gdb/gdbinit" 2>/dev/null; then
              echo "add-auto-load-safe-path $YSYX_HOME" >> "$HOME/.config/gdb/gdbinit"
            fi

            # GDB Dashboard 自动下载/更新
            # https://github.com/cyrus-and/gdb-dashboard
            GDBINIT_PATH="$YSYX_HOME/.gdbinit"
            if [ ! -f "$GDBINIT_PATH" ]; then
              echo "📥 下载 gdb-dashboard..."
              curl -fsSL https://raw.githubusercontent.com/cyrus-and/gdb-dashboard/master/.gdbinit -o "$GDBINIT_PATH"
            fi

            echo "🚀 YSYX 开发环境已加载!"
            echo "   NEMU_HOME:    $NEMU_HOME"
            echo "   AM_HOME:      $AM_HOME"
            echo "   NPC_HOME:     $NPC_HOME"
            echo "   NVBOARD_HOME: $NVBOARD_HOME"
            echo "   YOSYS_STA_HOME: $YOSYS_STA_HOME"
            echo ""
            echo "📦 可用工具: gcc, verilator, gdb, iverilog..."
             echo "🔧 RISC-V 工具链: $CROSS_COMPILE"
          '';

          # 确保 C/C++ 编译器能找到头文件和库
          hardeningDisable = [ "all" ];

          # NIX_CFLAGS_COMPILE 和 NIX_LDFLAGS 会自动设置
        };
      }
    );
}
