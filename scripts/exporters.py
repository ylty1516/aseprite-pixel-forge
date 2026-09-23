"""素材导出：单图复制重命名、PIL 图集打包 + JSON。"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


def export_pngs(png_paths, out_dir, prefix: str = "sprite") -> list:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    exported = []
    for i, src in enumerate(png_paths, start=1):
        dst = out / f"{prefix}_{i:02d}.png"
        dst.write_bytes(Path(src).read_bytes())
        exported.append(dst)
    return exported


def export_sheet(png_paths, out_png, out_json, columns: int = 8) -> tuple:
    """把若干等尺寸 PNG 打包为图集 + 帧坐标 JSON。"""
    imgs = [Image.open(p).convert("RGBA") for p in png_paths]
    if not imgs:
        raise ValueError("没有可导出的图片")
    cell_w = max(im.width for im in imgs)
    cell_h = max(im.height for im in imgs)
    rows = (len(imgs) + columns - 1) // columns
    sheet = Image.new("RGBA", (cell_w * min(columns, len(imgs)), cell_h * rows), (0, 0, 0, 0))
    frames = {}
    for i, (im, path) in enumerate(zip(imgs, png_paths)):
        x = (i % columns) * cell_w
        y = (i // columns) * cell_h
        sheet.paste(im, (x, y), im)
        frames[Path(path).stem] = {"x": x, "y": y, "w": im.width, "h": im.height}

    out_png = Path(out_png)
    out_png.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_png)
    out_json = Path(out_json)
    out_json.write_text(json.dumps({
        "frames": frames,
        "meta": {
            "image": out_png.name,
            "size": [sheet.width, sheet.height],
            "frame_count": len(frames),
            "cell": [cell_w, cell_h],
        },
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    return out_png, out_json
