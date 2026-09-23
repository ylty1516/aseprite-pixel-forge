import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_px_lua_suite(aseprite_path):
    """在 Aseprite 内跑 px.lua 金样断言（无 Aseprite 时自动 skip）。"""
    runner = ROOT / "tests" / "lua" / "run_px_tests.py"
    proc = subprocess.run([sys.executable, str(runner)], capture_output=True, text=True)
    assert proc.returncode == 0, proc.stdout + "\n" + proc.stderr
    assert "failed" in proc.stdout
