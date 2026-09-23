"""六大配方 × 全 choice 变体生成矩阵（真实 Aseprite；较慢但覆盖全参数域选项）。"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
FORGE = ROOT / "scripts" / "forge.py"
STYLE = "styles/left-hand-of-god.json"

CASES = []
for k in ("broadleaf", "dead", "conifer"):
    CASES.append(("tree", {"kind": k}))
for p in ("moss", "foliage_dark", "foliage_dead"):
    CASES.append(("bush", {"palette": p}))
for s in ("small", "medium", "large"):
    CASES.append(("rock", {"size": s}))
for k in ("tuft", "lily", "fern"):
    CASES.append(("flower", {"kind": k}))
for k in ("grass", "dirt", "cobble", "stone_floor"):
    CASES.append(("tile", {"kind": k}))
for k in ("column", "bricks", "arch"):
    CASES.append(("ruin", {"kind": k}))

IDS = [f"{r}-{list(p.values())[0]}" for r, p in CASES]


def run_forge(*args):
    return subprocess.run(
        [sys.executable, str(FORGE), *args],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(ROOT), timeout=600)


@pytest.mark.parametrize("recipe,params", CASES, ids=IDS)
def test_recipe_variant_generates_and_palette_ok(aseprite_path, tmp_path, recipe, params):
    out = tmp_path / recipe
    args = ["gen", recipe, "--style", STYLE, "--out", str(out),
            "--count", "1", "--seed", "42"]
    for key, value in params.items():
        args += ["--param", f"{key}={value}"]
    r = run_forge(*args)
    assert r.returncode == 0, r.stdout + r.stderr
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    c = manifest["candidates"][0]
    assert c["ok"], c["error"]

    r = run_forge("check", str(out), "--strict")
    assert r.returncode == 0, r.stdout + r.stderr
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["candidates"][0]["metrics"]["palette_ok"]
