"""CLI 错误路径与退出码（需要 Aseprite 的用例带 aseprite_path fixture）。"""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORGE = ROOT / "scripts" / "forge.py"
STYLE = "styles/left-hand-of-god.json"

THIN_STYLE = {
    "name": "thin",
    "canvas": {"tile": 16, "default_size": 16},
    "lighting": {"direction": "top-left"},
    "outline": {"policy": "selective", "color": "#0d0a12"},
    "detail": {"dither": "sparse"},
    "palette": {"ramps": {"stone": ["#262233", "#9993ac"]},
                "utility": {"outline": "#0d0a12"}},
}


def run_forge(*args, cwd=None):
    return subprocess.run(
        [sys.executable, str(FORGE), *args],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(cwd or ROOT), timeout=600)


def test_gen_all_failed_nonzero_and_error_recorded(aseprite_path, tmp_path):
    bad = tmp_path / "bad.lua"
    bad.write_text(
        "return {name='bad', category='debug', size={16,16}, params={},\n"
        " generate=function(ctx) error('boom-测试故意失败') end}\n",
        encoding="utf-8")
    out = tmp_path / "b"
    r = run_forge("gen", str(bad), "--style", STYLE,
                  "--out", str(out), "--count", "2", "--seed", "1")
    assert r.returncode == 1, r.stdout + r.stderr
    assert "Traceback" not in r.stderr
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    for c in manifest["candidates"]:
        assert c["ok"] is False
        assert c["error"] and "boom" in c["error"]
        assert c["timeout"] is False


def test_gen_invalid_choice_rejected(aseprite_path, tmp_path):
    r = run_forge("gen", "tree", "--style", STYLE, "--out", str(tmp_path / "g"),
                  "--count", "1", "--param", "kind=bogus")
    assert r.returncode == 1, r.stdout + r.stderr
    assert "bogus" in r.stdout and "broadleaf" in r.stdout


def test_gen_invalid_int_rejected(aseprite_path, tmp_path):
    r = run_forge("gen", "tree", "--style", STYLE, "--out", str(tmp_path / "g"),
                  "--count", "1", "--param", "height=abc")
    assert r.returncode == 1, r.stdout + r.stderr
    assert "非法" in r.stdout


def test_gen_unknown_param_rejected(aseprite_path, tmp_path):
    r = run_forge("gen", "smoke", "--style", STYLE, "--out", str(tmp_path / "g"),
                  "--count", "1", "--param", "nope=1")
    assert r.returncode == 1, r.stdout + r.stderr
    assert "未知参数" in r.stdout


def test_check_missing_manifest_friendly(tmp_path):
    r = run_forge("check", str(tmp_path / "empty"))
    assert r.returncode == 1
    combined = r.stdout + r.stderr
    assert "manifest" in combined
    assert "Traceback" not in combined


def test_check_strict_fails_on_bad_palette(aseprite_path, tmp_path):
    thin = tmp_path / "thin.json"
    thin.write_text(json.dumps(THIN_STYLE), encoding="utf-8")
    out = tmp_path / "g"
    r = run_forge("gen", "smoke", "--style", STYLE, "--out", str(out),
                  "--count", "1", "--seed", "1")
    assert r.returncode == 0, r.stdout + r.stderr
    r = run_forge("check", str(out), "--style", str(thin), "--strict")
    assert r.returncode == 1, r.stdout + r.stderr
    assert "色板违规" in r.stdout


def test_evolve_out_of_range_index(aseprite_path, tmp_path):
    out = tmp_path / "g"
    r = run_forge("gen", "smoke", "--style", STYLE, "--out", str(out),
                  "--count", "1", "--seed", "1")
    assert r.returncode == 0, r.stdout + r.stderr
    r = run_forge("evolve", str(out), "--keep", "99", "--out", str(tmp_path / "g2"))
    assert r.returncode == 1
    assert "超出范围" in r.stdout
