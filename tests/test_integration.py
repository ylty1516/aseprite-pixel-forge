"""端到端集成测试（需要 Aseprite；缺失时 skip）。"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
FORGE = ROOT / "scripts" / "forge.py"
STYLE = "styles/left-hand-of-god.json"


def run_forge(*args, cwd=None):
    return subprocess.run(
        [sys.executable, str(FORGE), *args],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(cwd or ROOT), timeout=600)


def _manifest(build: Path) -> dict:
    return json.loads((build / "manifest.json").read_text(encoding="utf-8"))


def test_doctor_passes(aseprite_path):
    r = run_forge("doctor")
    assert r.returncode == 0, r.stdout + r.stderr
    assert "doctor 全部通过" in r.stdout


def test_gen_single_and_determinism(aseprite_path, tmp_path):
    for sub in ("a", "b"):
        r = run_forge("gen", "smoke", "--style", STYLE,
                      "--out", str(tmp_path / sub), "--count", "1", "--seed", "7")
        assert r.returncode == 0, r.stdout + r.stderr
    ma, mb = _manifest(tmp_path / "a"), _manifest(tmp_path / "b")
    ca, cb = ma["candidates"][0], mb["candidates"][0]
    assert ca["ok"] and cb["ok"], (ca["error"], cb["error"])
    pa = tmp_path / "a" / f"{ca['id']}.png"
    pb = tmp_path / "b" / f"{cb['id']}.png"
    assert pa.is_file() and (tmp_path / "a" / f"{ca['id']}.aseprite").is_file()
    assert pa.read_bytes() == pb.read_bytes(), "同 seed 生成应完全一致"
    assert ca["params"] == cb["params"]


def test_gen_batch_check_and_preview(aseprite_path, tmp_path):
    build = tmp_path / "g"
    r = run_forge("gen", "smoke", "--style", STYLE,
                  "--out", str(build), "--count", "3", "--seed", "100")
    assert r.returncode == 0, r.stdout + r.stderr
    manifest = _manifest(build)
    assert len(manifest["candidates"]) == 3
    assert all(c["ok"] for c in manifest["candidates"])

    r = run_forge("check", str(build), "--style", STYLE, "--strict")
    assert r.returncode == 0, r.stdout + r.stderr
    manifest = _manifest(build)
    for c in manifest["candidates"]:
        assert c["metrics"]["palette_ok"], c["metrics"]["palette_bad_colors"]

    r = run_forge("preview", str(build))
    assert r.returncode == 0, r.stdout + r.stderr
    assert (build / "preview.png").is_file()


def test_evolve_and_export(aseprite_path, tmp_path):
    build = tmp_path / "g"
    r = run_forge("gen", "smoke", "--style", STYLE,
                  "--out", str(build), "--count", "4", "--seed", "200")
    assert r.returncode == 0, r.stdout + r.stderr

    out2 = tmp_path / "g2"
    r = run_forge("evolve", str(build), "--keep", "1,3", "--out", str(out2))
    assert r.returncode == 0, r.stdout + r.stderr
    # 父本轮被标记 selected（manifest 契约）
    m1 = _manifest(build)
    selected = {c["id"] for c in m1["candidates"] if c["selected"]}
    assert selected == {"smoke_001", "smoke_003"}
    m2 = _manifest(out2)
    assert m2["round"] == 2
    assert m2["parents"] == ["smoke_001", "smoke_003"]
    assert len(m2["candidates"]) == 2
    assert all(c["ok"] for c in m2["candidates"])

    r = run_forge("check", str(out2), "--strict")
    assert r.returncode == 0, r.stdout + r.stderr

    pack_dir = tmp_path / "pack"
    r = run_forge("export", str(out2), "--out", str(pack_dir), "--sheet")
    assert r.returncode == 0, r.stdout + r.stderr
    pack = json.loads((pack_dir / "pack.json").read_text(encoding="utf-8"))
    assert len(pack["exported"]) == 2
    assert (pack_dir / "smoke_01.png").is_file()
    assert (pack_dir / "smoke_sheet.png").is_file()
    assert (pack_dir / "smoke_sheet.json").is_file()
    assert (pack_dir / "source_aseprite").is_dir()


def test_export_refuses_bad_palette(aseprite_path, tmp_path):
    """构造一个色板违规场景：用只含 2 色的 style 去导出 smoke 图。"""
    thin_style = tmp_path / "thin.json"
    thin_style.write_text(json.dumps({
        "name": "thin",
        "canvas": {"tile": 16, "default_size": 16},
        "lighting": {"direction": "top-left"},
        "outline": {"policy": "selective", "color": "#0d0a12"},
        "detail": {"dither": "sparse"},
        "palette": {"ramps": {"stone": ["#262233", "#9993ac"]},
                    "utility": {"outline": "#0d0a12"}},
    }), encoding="utf-8")

    build = tmp_path / "g"
    r = run_forge("gen", "smoke", "--style", STYLE,
                  "--out", str(build), "--count", "1", "--seed", "1")
    assert r.returncode == 0, r.stdout + r.stderr
    # 用薄色板 style 质检 → 必然违规
    r = run_forge("check", str(build), "--style", str(thin_style))
    assert r.returncode == 0, r.stdout + r.stderr
    manifest = _manifest(build)
    assert manifest["candidates"][0]["metrics"]["palette_ok"] is False

    r = run_forge("export", str(build), "--out", str(tmp_path / "pack"),
                  "--style", str(thin_style))
    assert r.returncode == 1
    assert "拒绝" in r.stdout
