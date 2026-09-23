import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_px_lua_suite(aseprite_path):
    """在 Aseprite 内跑 px.lua 金样断言（无 Aseprite 时自动 skip）。"""
    import re

    runner = ROOT / "tests" / "lua" / "run_px_tests.py"
    proc = subprocess.run([sys.executable, str(runner)], capture_output=True, text=True)
    assert proc.returncode == 0, proc.stdout + "\n" + proc.stderr
    m = re.search(r"(\d+) checks, (\d+) failed", proc.stdout)
    assert m, f"无法解析断言汇总:\n{proc.stdout}"
    checks, failed = int(m.group(1)), int(m.group(2))
    assert failed == 0, proc.stdout
    assert checks >= 30, f"Lua 断言数量异常偏少：{checks}"
