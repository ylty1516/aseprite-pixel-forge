import json

import pytest
from PIL import Image

from style import (
    StyleError,
    check_png_compliance,
    export_gpl,
    iterate_palette,
    load_style,
    parse_direction,
    parse_hex,
    validate_style,
    write_style_lua,
)

MINIMAL = {
    "name": "test-style",
    "canvas": {"tile": 16, "default_size": 16},
    "lighting": {"direction": "top-left"},
    "outline": {"policy": "selective", "color": "#0d0a12"},
    "detail": {"dither": "sparse"},
    "palette": {
        "ramps": {"stone": ["#202020", "#606060", "#a0a0a0"]},
        "utility": {"outline": "#0d0a12"},
    },
}


def test_parse_hex():
    assert parse_hex("#0d0a12") == (13, 10, 18)
    with pytest.raises(StyleError):
        parse_hex("0d0a12")
    with pytest.raises(StyleError):
        parse_hex("#12345")


def test_parse_direction():
    assert parse_direction("top-left") == (-1, -1)
    assert parse_direction("bottom-right") == (1, 1)
    assert parse_direction("top") == (0, -1)
    with pytest.raises(StyleError):
        parse_direction("diagonal")


def test_validate_ok():
    assert validate_style(MINIMAL) == []


def test_validate_missing_fields():
    errors = validate_style({"name": "x"})
    assert any("canvas" in e for e in errors)
    assert any("palette" in e for e in errors)


def test_validate_bad_hex():
    bad = json.loads(json.dumps(MINIMAL))
    bad["palette"]["ramps"]["stone"][0] = "zzz"
    assert any("hex" in e.lower() or "颜色" in e for e in validate_style(bad))


def test_validate_bad_outline_policy():
    bad = json.loads(json.dumps(MINIMAL))
    bad["outline"]["policy"] = "sometimes"
    assert any("policy" in e for e in validate_style(bad))


def test_load_style_roundtrip(tmp_path):
    p = tmp_path / "s.json"
    p.write_text(json.dumps(MINIMAL), encoding="utf-8")
    style = load_style(p)
    assert style["name"] == "test-style"


def test_load_style_invalid_raises(tmp_path):
    p = tmp_path / "s.json"
    p.write_text(json.dumps({"name": "x"}), encoding="utf-8")
    with pytest.raises(StyleError):
        load_style(p)


def test_export_gpl(tmp_path):
    out = export_gpl(MINIMAL, tmp_path / "p.gpl")
    text = out.read_text(encoding="utf-8")
    assert text.startswith("GIMP Palette")
    assert "#202020" not in text  # GPL 十进制格式
    flat = " ".join(text.split())
    assert "32 32 32 stone_1" in flat
    assert "13 10 18 outline" in flat
    assert "a0a0a0" not in text.lower()


def test_write_style_lua(tmp_path):
    out = write_style_lua(MINIMAL, tmp_path / "s.lua")
    text = out.read_text(encoding="utf-8")
    assert 'stone' in text
    assert 'r=32' in text and 'b=32' in text  # rgba 表形式
    assert '-1' in text and 'selective' in text
    assert 'default_size = 16' in text


def test_iterate_palette():
    colors = iterate_palette(MINIMAL)
    assert (0x0D, 0x0A, 0x12) in colors
    assert (0xA0, 0xA0, 0xA0) in colors


def _png(tmp_path, pixels):
    img = Image.new("RGBA", (2, 2))
    img.putdata(pixels)
    p = tmp_path / "t.png"
    img.save(p)
    return p


def test_check_png_compliance_ok(tmp_path):
    a, b = (32, 32, 32, 255), (96, 96, 96, 255)
    p = _png(tmp_path, [a, b, a, b])
    rep = check_png_compliance(p, MINIMAL)
    assert rep["ok"] is True
    assert rep["bad"] == 0


def test_check_png_compliance_bad_color(tmp_path):
    a, off = (32, 32, 32, 255), (200, 0, 0, 255)
    p = _png(tmp_path, [a, off, a, a])
    rep = check_png_compliance(p, MINIMAL)
    assert rep["ok"] is False
    assert rep["bad"] == 1
    assert "#c80000" in rep["bad_colors"]


def test_check_png_compliance_transparent_ignored(tmp_path):
    a, clear = (32, 32, 32, 255), (123, 45, 200, 0)
    p = _png(tmp_path, [a, clear, a, a])
    rep = check_png_compliance(p, MINIMAL)
    assert rep["ok"] is True


def test_check_png_compliance_partial_alpha_bad(tmp_path):
    a, half = (32, 32, 32, 255), (96, 96, 96, 128)
    p = _png(tmp_path, [a, half, a, a])
    rep = check_png_compliance(p, MINIMAL)
    assert rep["ok"] is False
