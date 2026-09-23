"""style spec 加载/校验/派生（.gpl 色板、_style.lua、色板合规判定）。"""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image

HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
DIRECTIONS = {
    "top-left": (-1, -1), "top": (0, -1), "top-right": (1, -1),
    "left": (-1, 0), "right": (1, 0),
    "bottom-left": (-1, 1), "bottom": (0, 1), "bottom-right": (1, 1),
}
OUTLINE_POLICIES = {"selective", "full", "none"}
DITHER_LEVELS = {"none", "sparse", "medium"}


class StyleError(ValueError):
    pass


# ---------------------------------------------------------------- 基础

def parse_hex(value: str) -> tuple:
    if not isinstance(value, str) or not HEX_RE.match(value):
        raise StyleError(f"非法颜色 hex: {value!r}（应为 #RRGGBB）")
    return (int(value[1:3], 16), int(value[3:5], 16), int(value[5:7], 16))


def parse_direction(name: str) -> tuple:
    if name not in DIRECTIONS:
        raise StyleError(f"非法光照方向: {name!r}，可选 {sorted(DIRECTIONS)}")
    return DIRECTIONS[name]


# ---------------------------------------------------------------- 校验

def validate_style(style: dict) -> list:
    errors: list = []
    if not isinstance(style, dict):
        return ["style 必须是 JSON 对象"]

    if not style.get("name"):
        errors.append("缺少 name")

    canvas = style.get("canvas")
    if not isinstance(canvas, dict) or not isinstance(canvas.get("default_size"), int):
        errors.append("缺少 canvas.default_size（整数）")

    lighting = style.get("lighting")
    if not isinstance(lighting, dict) or lighting.get("direction") not in DIRECTIONS:
        errors.append(f"lighting.direction 必须是 {sorted(DIRECTIONS)} 之一")

    outline = style.get("outline")
    if not isinstance(outline, dict):
        errors.append("缺少 outline 段")
    else:
        if outline.get("policy") not in OUTLINE_POLICIES:
            errors.append(f"outline.policy 必须是 {sorted(OUTLINE_POLICIES)} 之一")
        if "color" in outline:
            try:
                parse_hex(outline["color"])
            except StyleError as e:
                errors.append(str(e))

    detail = style.get("detail", {})
    if detail.get("dither") is not None and detail.get("dither") not in DITHER_LEVELS:
        errors.append(f"detail.dither 必须是 {sorted(DITHER_LEVELS)} 之一")

    palette = style.get("palette")
    if not isinstance(palette, dict) or not isinstance(palette.get("ramps"), dict):
        errors.append("缺少 palette.ramps")
    else:
        for ramp_name, ramp in palette["ramps"].items():
            if not isinstance(ramp, list) or len(ramp) < 2:
                errors.append(f"色阶 {ramp_name} 至少需要 2 个颜色")
                continue
            for color in ramp:
                try:
                    parse_hex(color)
                except StyleError as e:
                    errors.append(f"{ramp_name}: {e}")
        for key, color in (palette.get("utility") or {}).items():
            try:
                parse_hex(color)
            except StyleError as e:
                errors.append(f"utility.{key}: {e}")
    return errors


def load_style(path) -> dict:
    p = Path(path)
    try:
        style = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise StyleError(f"无法读取 style 文件 {p}: {e}") from e
    errors = validate_style(style)
    if errors:
        raise StyleError("style 校验失败:\n  - " + "\n  - ".join(errors))
    return style


# ---------------------------------------------------------------- 派生

def iterate_palette(style: dict) -> list:
    colors = []
    for ramp in style["palette"]["ramps"].values():
        colors.extend(parse_hex(c) for c in ramp)
    colors.extend(parse_hex(c) for c in (style["palette"].get("utility") or {}).values())
    outline_color = (style.get("outline") or {}).get("color")
    if outline_color:
        colors.append(parse_hex(outline_color))
    return colors


def export_gpl(style: dict, out_path) -> Path:
    lines = ["GIMP Palette", f"Name: {style['name']}", "Columns: 8", "#"]
    for ramp_name, ramp in style["palette"]["ramps"].items():
        for i, color in enumerate(ramp):
            r, g, b = parse_hex(color)
            lines.append(f"{r:3d} {g:3d} {b:3d}\t{ramp_name}_{i + 1}")
    for key, color in (style["palette"].get("utility") or {}).items():
        r, g, b = parse_hex(color)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{key}")
    out = Path(out_path)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out


def _quote(text: str) -> str:
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _hex_to_rgba_expr(color: str) -> str:
    r, g, b = parse_hex(color)
    return f"{{r={r},g={g},b={b},a=255}}"


def write_style_lua(style: dict, out_path) -> Path:
    """生成供配方 dofile 的 _style.lua。"""
    dx, dy = parse_direction(style["lighting"]["direction"])
    parts = ["-- 自动生成，勿手改：由 aseprite-pixel-forge style 命令派生", "return {"]
    parts.append(f"  name = {_quote(style['name'])},")
    parts.append(f"  default_size = {int(style['canvas']['default_size'])},")
    tile = style["canvas"].get("tile")
    parts.append(f"  tile = {int(tile) if tile else 'nil'},")
    parts.append(f"  lighting = {{ dx = {dx}, dy = {dy} }},")
    outline = style["outline"]
    parts.append(
        f"  outline = {{ policy = {_quote(outline['policy'])}, "
        f"color = {_hex_to_rgba_expr(outline['color'])} }},"
    )
    parts.append(f"  dither = {_quote(style.get('detail', {}).get('dither', 'sparse'))},")
    parts.append("  ramps = {")
    for ramp_name, ramp in sorted(style["palette"]["ramps"].items()):
        colors = ", ".join(_hex_to_rgba_expr(c) for c in ramp)
        parts.append(f"    {ramp_name} = {{ {colors} }},")
    parts.append("  },")
    parts.append("}")
    out = Path(out_path)
    out.write_text("\n".join(parts) + "\n", encoding="utf-8")
    return out


# ---------------------------------------------------------------- 合规

def check_png_compliance(png_path, style: dict) -> dict:
    """检查 PNG 不透明像素是否全部 ∈ 色板。透明像素忽略；半透明视为违规。"""
    allowed = set(iterate_palette(style))
    img = Image.open(png_path).convert("RGBA")
    total = 0
    bad_colors = {}
    for r, g, b, a in img.getdata():
        if a == 0:
            continue
        total += 1
        if a != 255 or (r, g, b) not in allowed:
            key = f"#{r:02x}{g:02x}{b:02x}" + ("" if a == 255 else f"@{a}")
            bad_colors[key] = bad_colors.get(key, 0) + 1
    bad = sum(bad_colors.values())
    return {
        "ok": bad == 0,
        "total": total,
        "bad": bad,
        "bad_colors": sorted(bad_colors, key=bad_colors.get, reverse=True)[:12],
    }
