import json
import random
from pathlib import Path

import pytest
from PIL import Image

import exporters
import quality

STYLE = {
    "name": "t",
    "canvas": {"tile": 8, "default_size": 8},
    "lighting": {"direction": "top-left"},
    "outline": {"policy": "selective", "color": "#0d0a12"},
    "detail": {"dither": "sparse"},
    "palette": {"ramps": {"k": ["#202020", "#606060"]}, "utility": {"outline": "#0d0a12"}},
}


def _png(tmp_path, name="a.png", size=(8, 8), pixel=None, edge=False, empty=False):
    img = Image.new("RGBA", tuple(size), (0, 0, 0, 0))
    if not empty:
        color = pixel or (0x20, 0x20, 0x20, 255)
        pos = (0, 0) if edge else (size[0] // 2, size[1] // 2)
        img.putpixel(pos, color)
    p = tmp_path / name
    img.save(p)
    return p


def test_png_metrics_basic(tmp_path):
    p = _png(tmp_path)
    m = quality.png_metrics(p, STYLE)
    assert m["size"] == [8, 8]
    assert m["pixels"] == 1 and m["colors"] == 1
    assert m["palette_ok"] and not m["empty"]
    assert m["edges"] == []
    assert len(m["sha256"]) == 64


def test_png_metrics_bad_palette_and_edge_and_empty(tmp_path):
    bad = _png(tmp_path, "bad.png", pixel=(200, 0, 0, 255), edge=True)
    m = quality.png_metrics(bad, STYLE)
    assert m["palette_ok"] is False and m["palette_bad"] == 1
    assert "top" in m["edges"] and "left" in m["edges"]

    empty = _png(tmp_path, "empty.png", empty=True)
    m2 = quality.png_metrics(empty, STYLE)
    assert m2["empty"] is True and m2["pixels"] == 0


def test_contact_sheet_layout(tmp_path):
    paths = [_png(tmp_path, f"{i}.png") for i in range(3)]
    sheet, layout = quality.contact_sheet(paths, scale=4, cols=2)
    assert sheet.width > 0 and sheet.height > 0
    assert [x["index"] for x in layout] == [1, 2, 3]
    assert layout[0]["name"] == "0.png"
    # 两列布局：第 3 个在第二行
    assert layout[2]["y"] > layout[0]["y"]


def test_mutate_params_deterministic_and_bounded():
    specs = {
        "n": {"type": "int", "min": 2, "max": 10, "default": 5},
        "f": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.5},
        "b": {"type": "bool", "default": True},
        "c": {"type": "choice", "values": ["a", "b", "c"], "default": "a"},
    }
    parent = {"n": 5, "f": 0.5, "b": True, "c": "a"}
    r1 = quality.mutate_params(parent, specs, random.Random(42), jitter=0.5)
    r2 = quality.mutate_params(parent, specs, random.Random(42), jitter=0.5)
    assert r1 == r2
    for _ in range(50):
        r = quality.mutate_params(parent, specs, random.Random(random.random()), jitter=0.6)
        assert 2 <= r["n"] <= 10
        assert 0.0 <= r["f"] <= 1.0
        assert r["c"] in ("a", "b", "c")


def test_export_pngs_renames(tmp_path):
    src = tmp_path / "src"
    src.mkdir()
    paths = [_png(src, f"c{i}.png") for i in range(2)]
    out = exporters.export_pngs([str(p) for p in paths], tmp_path / "out", prefix="tree")
    names = sorted(p.name for p in out)
    assert names == ["tree_01.png", "tree_02.png"]


def test_export_sheet_coordinates(tmp_path):
    src = tmp_path / "src"
    src.mkdir()
    paths = [_png(src, "a.png"), _png(src, "b.png")]
    sheet_png, sheet_json = exporters.export_sheet(
        [str(p) for p in paths], tmp_path / "s.png", tmp_path / "s.json", columns=2)
    assert sheet_png.is_file() and sheet_json.is_file()
    data = json.loads(sheet_json.read_text(encoding="utf-8"))
    assert data["frames"]["a"] == {"x": 0, "y": 0, "w": 8, "h": 8}
    assert data["frames"]["b"] == {"x": 8, "y": 0, "w": 8, "h": 8}
    assert data["meta"]["size"] == [16, 8]
    img = Image.open(sheet_png)
    assert img.size == (16, 8)


def test_sample_and_mutate_respect_non_sample_params():
    import importlib
    import random as _random

    forge = importlib.import_module("forge")
    specs = {
        "a": {"type": "int", "min": 1, "max": 9, "default": 3},
        "frames": {"type": "int", "min": 1, "max": 6, "default": 1, "sample": False},
    }
    p = forge.sample_params(specs, _random.Random(0))
    assert p["frames"] == 1
    mutated = quality.mutate_params({"a": 5, "frames": 4}, specs,
                                    _random.Random(0), jitter=0.9)
    assert mutated["frames"] == 4  # 非采样参数在进化中保持不变


def test_export_sheet_wraps_rows(tmp_path):
    src = tmp_path / "src"
    src.mkdir()
    paths = [_png(src, f"{i}.png") for i in range(3)]
    _, sheet_json = exporters.export_sheet(
        [str(p) for p in paths], tmp_path / "s.png", tmp_path / "s.json", columns=2)
    data = json.loads(sheet_json.read_text(encoding="utf-8"))
    assert data["frames"]["2"] == {"x": 0, "y": 8, "w": 8, "h": 8}
    assert data["meta"]["size"] == [16, 16]
