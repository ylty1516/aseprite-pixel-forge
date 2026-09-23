"""数值质检、预览渲染、联系表、参数进化。"""

from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from style import check_png_compliance


# ---------------------------------------------------------------- 指标

def png_metrics(png_path, style: dict) -> dict:
    p = Path(png_path)
    img = Image.open(p).convert("RGBA")
    w, h = img.size
    data = list(img.getdata())

    total, colors = 0, set()
    brightness_sum = 0.0
    for i, (r, g, b, a) in enumerate(data):
        if a == 0:
            continue
        total += 1
        colors.add((r, g, b))
        brightness_sum += 0.299 * r + 0.587 * g + 0.114 * b

    edges = []
    if any(data[x][3] > 0 for x in range(w)):
        edges.append("top")
    if any(data[(h - 1) * w + x][3] > 0 for x in range(w)):
        edges.append("bottom")
    if any(data[y * w][3] > 0 for y in range(h)):
        edges.append("left")
    if any(data[y * w + w - 1][3] > 0 for y in range(h)):
        edges.append("right")

    compliance = check_png_compliance(p, style)
    return {
        "size": [w, h],
        "pixels": total,
        "colors": len(colors),
        "empty": total == 0,
        "edges": edges,
        "palette_ok": compliance["ok"],
        "palette_bad": compliance["bad"],
        "palette_bad_colors": compliance["bad_colors"],
        "brightness": round(brightness_sum / total, 1) if total else 0.0,
        "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
    }


# ---------------------------------------------------------------- 预览

_LABEL_FONTS = {}


def _font(size: int):
    if size not in _LABEL_FONTS:
        try:
            _LABEL_FONTS[size] = ImageFont.load_default(size=size)
        except TypeError:  # 旧版 PIL
            _LABEL_FONTS[size] = ImageFont.load_default()
    return _LABEL_FONTS[size]


def _upscale(img: Image.Image, scale: int) -> Image.Image:
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def contact_sheet(pngs, scale: int = 6, cols: int = 6, pad: int = 10,
                  bg=(24, 24, 30), label_color=(235, 235, 240)) -> tuple:
    """每格：放大图 + 1x 原尺寸图并排，编号标签。返回 (PIL.Image, layout)。

    layout: [{"index": 1-based, "name": 文件名, "x": 单元格左上 x, "y": ...}]
    """
    items = [Image.open(p).convert("RGBA") for p in pngs]
    if not items:
        raise ValueError("没有可预览的图片")
    layout = []
    label_h = 16
    cell_w = max(im.width * scale + 10 + im.width for im in items) + pad * 2
    cell_h = max(im.height * scale for im in items) + label_h + pad * 2
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cell_w * min(cols, len(items)), cell_h * rows), bg)
    draw = ImageDraw.Draw(sheet)
    for i, (im, path) in enumerate(zip(items, pngs)):
        cx = (i % cols) * cell_w
        cy = (i // cols) * cell_h
        draw.text((cx + pad, cy + 2), f"{i + 1}", fill=label_color, font=_font(14))
        big = _upscale(im, scale)
        sheet.paste(big, (cx + pad, cy + label_h + pad), big)
        sheet.paste(im, (cx + pad + big.width + 10, cy + label_h + pad), im)
        layout.append({
            "index": i + 1,
            "name": Path(path).name,
            "x": cx, "y": cy,
        })
    return sheet, layout


# ---------------------------------------------------------------- 进化

def mutate_params(parent: dict, specs: dict, rng: random.Random,
                  jitter: float = 0.25) -> dict:
    """在参数范围内对父本参数做确定性扰动（排序遍历保确定性）。"""
    out = {}
    for key, spec in sorted(specs.items()):
        if spec.get("sample") is False:
            # 非采样参数（frames/fps 等）保持父本值
            out[key] = parent.get(key, spec.get("default"))
            continue
        v = parent.get(key, spec.get("default"))
        t = spec.get("type")
        if t in ("int", "float"):
            lo, hi = spec.get("min", 0), spec.get("max", 1)
            span = hi - lo or 1
            nv = v + rng.uniform(-jitter, jitter) * span
            nv = max(lo, min(hi, nv))
            out[key] = int(round(nv)) if t == "int" else round(nv, 4)
        elif t == "bool":
            out[key] = (not v) if rng.random() < jitter else v
        elif t == "choice":
            values = list(spec.get("values", []))
            others = [c for c in values if c != v]
            if others and rng.random() < jitter:
                out[key] = rng.choice(others)
            else:
                out[key] = v
        else:
            out[key] = v
    return out


# ---------------------------------------------------------------- manifest

def load_manifest(build_dir) -> dict:
    p = Path(build_dir) / "manifest.json"
    return json.loads(p.read_text(encoding="utf-8"))


def save_manifest(build_dir, manifest: dict) -> Path:
    p = Path(build_dir) / "manifest.json"
    p.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return p
