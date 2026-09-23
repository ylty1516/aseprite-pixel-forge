"""运行 tests/lua/test_px.lua 并汇总断言结果。退出码 0=全过。"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from aseprite_runner import run_script  # noqa: E402


def main() -> int:
    script = ROOT / "tests" / "lua" / "test_px.lua"
    res = run_script(script, {"root": ROOT.as_posix()}, timeout=180)
    forge = res.get("forge")
    if not forge or not forge.get("ok"):
        print("FORGE 输出缺失或失败。")
        print("--- stdout ---\n" + res.get("stdout", ""))
        print("--- stderr ---\n" + res.get("stderr", ""))
        return 1
    fails = 0
    for item in forge.get("results", []):
        status = "PASS" if item.get("ok") else "FAIL"
        if not item.get("ok"):
            fails += 1
        line = f"{status} {item.get('name')}"
        if item.get("detail"):
            line += f"  [{item['detail']}]"
        print(line)
    print(f"\n{len(forge.get('results', []))} checks, {fails} failed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
