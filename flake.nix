{
  description = "YSYX (一生一芯) 开发环境";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # 旧版 nixpkgs，用于获取已移除的 gcc11
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-old,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # 从旧版 nixpkgs 获取 gcc11
        pkgsOld = import nixpkgs-old {
          inherit system;
        };

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import ./overlay.nix) ];
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
            pkg-config
            autoconf
            automake

            # ========================
            # C/C++ 工具链 (从旧版 nixpkgs 获取)
            # ========================
            pkgsOld.gcc11 # GCC 11.4
            pkgsOld.clang-tools_12 # clangd, clang-format 等 (LLVM 12)
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
            pkgsOld.llvmPackages_12.libllvm # LLVM 12
            libelf # gelf.h for ftrace
            dtc # spike

            # ========================
            # NPC (Chisel/Scala) 依赖
            # ========================
            jdk21
            scala_2_13
            circt # 包含 firtool，Chisel 生成 Verilog 需要
            metals # mill 不会自动下载
            mill_0_12_4 # 锁定到 0.12.4 版本

            # ========================
            # Verilog/仿真工具
            # ========================
            verilator
            gtkwave # 波形查看器 (可选)

            # ========================
            # NVBoard / 图形界面依赖
            # ========================
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
            # 实用工具
            # ========================
            git
            python3
            ruff # lsp of python
            bear # 生成 compile_commands.json
            ccache
          ];

          # 环境变量设置
          STUBS_ILP32_FIX = "${stubsIlp32Fix}/include";

          shellHook = ''
            # 设置项目根目录
            export YSYX_HOME="$(pwd)"
            export NEMU_HOME="$YSYX_HOME/nemu"
            export AM_HOME="$YSYX_HOME/abstract-machine"
            export NPC_HOME="$YSYX_HOME/npc"
            export NVBOARD_HOME="$YSYX_HOME/nvboard"

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

            # SDL2 配置
            export SDL2_CONFIG="${pkgs.SDL2}/bin/sdl2-config"

            # yosys-sta 路径
            export YOSYS_STA_HOME="$YSYX_HOME/yosys-sta"

            # GDB 自动加载安全路径配置
            # 确保 GDB 可以自动加载项目中的 .gdbinit 文件
            mkdir -p "$HOME/.config/gdb"
            if ! grep -q "add-auto-load-safe-path.*$NPC_HOME" "$HOME/.config/gdb/gdbinit" 2>/dev/null; then
              echo "add-auto-load-safe-path $NPC_HOME" >> "$HOME/.config/gdb/gdbinit"
            fi

            echo "🚀 YSYX 开发环境已加载!"
            echo "   NEMU_HOME:    $NEMU_HOME"
            echo "   AM_HOME:      $AM_HOME"
            echo "   NPC_HOME:     $NPC_HOME"
            echo "   NVBOARD_HOME: $NVBOARD_HOME"
            echo "   YOSYS_STA_HOME: $YOSYS_STA_HOME"
            echo ""
            echo "📦 可用工具: gcc, verilator, gdb..."
            echo "🔧 RISC-V 工具链: $CROSS_COMPILE"
          '';

          # 确保 C/C++ 编译器能找到头文件和库
          hardeningDisable = [ "all" ];

          # NIX_CFLAGS_COMPILE 和 NIX_LDFLAGS 会自动设置
        };
      }
    );
}
