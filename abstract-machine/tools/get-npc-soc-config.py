#!/usr/bin/env python3
"""
从 NPC 的 Meson 配置获取 SoC 地址映射，输出 Make 变量赋值。
优先使用 meson introspect（若 build 目录存在），否则解析 meson_options.txt 默认值。
"""
import json
import os
import re
import subprocess
import sys
from typing import Optional

# meson 选项名 -> npc.mk 变量名
SOC_OPT_MAP = [
    ('soc_mrom_base', 'MROM_BASE'),
    ('soc_mrom_size', 'MROM_SIZE'),
    ('soc_sram_base', 'SRAM_BASE'),
    ('soc_sram_size', 'SRAM_SIZE'),
    ('soc_flash_base', 'FLASH_BASE'),
    ('soc_flash_size', 'FLASH_SIZE'),
    ('soc_psram_base', 'PSRAM_BASE'),
    ('soc_psram_size', 'PSRAM_SIZE'),
    ('soc_sdram_base', 'SDRAM_BASE'),
    ('soc_sdram_size', 'SDRAM_SIZE'),
]


def get_from_meson_introspect(npc_home: str) -> Optional[dict]:
    """从 meson introspect 获取配置，失败返回 None。"""
    bdir = os.path.join(npc_home, 'build', 'meson')
    if not os.path.isdir(bdir):
        return None
    try:
        result = subprocess.run(
            ['meson', 'introspect', '--buildoptions', bdir],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return None
        opts = json.loads(result.stdout)
        return {o['name']: str(o['value']) for o in opts}
    except (json.JSONDecodeError, subprocess.TimeoutExpired, FileNotFoundError):
        return None


def get_from_meson_options(npc_home: str) -> dict:
    """从 meson_options.txt 解析默认值。"""
    path = os.path.join(npc_home, 'meson_options.txt')
    values = {}
    if not os.path.isfile(path):
        return values
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = re.match(r"option\('([^']+)',\s*type:\s*'[^']+',\s*value:\s*'([^']*)'", line)
            if m:
                values[m.group(1)] = m.group(2)
    return values


def main() -> None:
    npc_home = os.environ.get('NPC_HOME') or (sys.argv[1] if len(sys.argv) > 1 else '')
    if not npc_home or not os.path.isdir(npc_home):
        sys.stderr.write('get-npc-soc-config.py: NPC_HOME not set or invalid\n')
        sys.exit(1)

    config = get_from_meson_introspect(npc_home)
    if config is None:
        config = get_from_meson_options(npc_home)

    for opt_name, var_name in SOC_OPT_MAP:
        val = config.get(opt_name, '')
        print(f'{var_name} := {val}')


if __name__ == '__main__':
    main()
