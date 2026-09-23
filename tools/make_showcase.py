#!/usr/bin/env python3
"""构建 README 演示素材。

产出（assets/）：
  hero-scene.gif   960x540 场景动效（2x），12 帧
  hero-scene.png   静止首帧
  variants.gif     六品类变体轮播
  evolution.png    进化前后对比

动效说明（诚实标注）：所有动画均为对静态素材的程序化后处理
（帧位移摆动 / 颜色脉动 / 粒子），配方原生多帧动画在 v3 路线图。

用法： py -3 tools/make_showcase.py
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "examples" / "gothic-nature-pack"
ASSETS = ROOT / "assets"
sys.path.insert(0, str(ROOT / "scripts"))
from style import load_style, parse_hex  # noqa: E402

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

STYLE = load_style(ROOT / "styles" / "left-hand-of-god.json")
BG = parse_hex(STYLE["palette"]["ramps"]["shadow"][0])

GAME_W, GAME_H = 480, 270
SCALE = 2
FRAMES = 12
DURATION_MS = 100


# ---------------------------------------------------------------- 工具

def load_font(size: int, need_cjk: bool):
    candidates = [
        "C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/msyhl.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/System/Library/Fonts/PingFang.ttc",
    ]
    if need_cjk:
        for c in candidates:
            if Path(c).exists():
                try:
                    return ImageFont.truetype(c, size), True
                except OSError:
                    pass
    return ImageFont.load_default(size=size), False


FONT_18, HAS_CJK = load_font(20, True)
FONT_26 = load_font(30, True)[0] if HAS_CJK else ImageFont.load_default(size=30)


def load_sprites(folder: str) -> dict:
    out = {}
    for p in sorted((PACK / folder).glob("*.png")):
        if "_sheet" in p.name:
            continue
        out[p.stem] = Image.open(p).convert("RGBA")
    return out


def palette_levels(ramp_name: str) -> dict:
    """{rgba tuple: level}"""
    return {parse_hex(c) + (255,): i + 1
            for i, c in enumerate(STYLE["palette"]["ramps"][ramp_name])}


EMBER = palette_levels("ember")
FROST = palette_levels("frost")


def glow_map(sprite: Image.Image) -> dict:
    """检测发光像素（余烬/霜华高阶色）→ 脉动替换色映射。"""
    mapping = {}
    ember_colors = [c for c, lv in EMBER.items() if lv >= 4]
    frost_colors = [c for c, lv in FROST.items() if lv >= 5]
    for y in range(sprite.height):
        for x in range(sprite.width):
            c = sprite.getpixel((x, y))
            if c in ember_colors:
                lv = EMBER[c]
                mapping[c] = parse_hex(STYLE["palette"]["ramps"]["ember"][max(0, lv - 2)]) + (255,)
            elif c in frost_colors:
                mapping[c] = parse_hex(STYLE["palette"]["ramps"]["frost"][3]) + (255,)
    return mapping


def pulse(sprite: Image.Image, mapping: dict) -> Image.Image:
    if not mapping:
        return sprite
    out = sprite.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            c = px[x, y]
            if c in mapping:
                px[x, y] = mapping[c]
    return out


def paste_sway(base: Image.Image, sprite: Image.Image, pos, dx: int, split_ratio=0.42):
    """上半身水平偏移 dx 的"摆动"合成；补缝避免断裂。"""
    w, h = sprite.size
    ys = max(1, int(h * split_ratio))
    top = sprite.crop((0, 0, w, ys))
    bottom = sprite.crop((0, ys, w, h))
    px, py = pos
    base.alpha_composite(top, (px + dx, py))
    base.alpha_composite(bottom, (px, py + ys))
    if dx > 0:
        edge = top.crop((0, 0, 1, ys))
        for i in range(dx):
            base.alpha_composite(edge, (px + i, py))
    elif dx < 0:
        edge = top.crop((w - 1, 0, w, ys))
        for i in range(-dx):
            base.alpha_composite(edge, (px + w - 1 - i, py))


# ---------------------------------------------------------------- 场景

def build_scene():
    """返回 (背景, 舞台元素列表)。元素 = dict(sprite, x, y, kind, phase)"""
    rng = random.Random(20260923)
    grass = load_sprites("tiles")
    stage = []

    # 地面：草地铺满
    grass_tiles = [grass[k] for k in ("tile_02", "grass_01", "grass_02") if k in grass]
    ground = Image.new("RGBA", (GAME_W, GAME_H), BG + (255,))
    for ty in range(0, GAME_H, 32):
        for tx in range(0, GAME_W, 32):
            tile = grass_tiles[rng.randrange(len(grass_tiles))]
            if rng.random() < 0.5:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            ground.alpha_composite(tile, (tx, ty))

    # 泥路：左→右的波浪带
    dirt_tiles = [grass[k] for k in ("tile_01", "tile_05") if k in grass]
    for tx in range(-32, GAME_W + 32, 32):
        wy = int(196 - math.sin(tx / 110.0) * 26)
        tile = dirt_tiles[(tx // 32) % 2]
        ground.alpha_composite(tile, (tx, wy))
        ground.alpha_composite(tile, (tx, wy + 32))

    # 石板庭院（右中）
    cobble = [grass[k] for k in ("tile_03", "tile_07") if k in grass]
    for ty in range(128, 256, 32):
        for tx in range(288, GAME_W, 32):
            ground.alpha_composite(cobble[rng.randrange(len(cobble))], (tx, ty))
    slabs = [grass[k] for k in ("tile_04", "tile_06") if k in grass]
    for ty in (160, 192):
        for tx in (320, 352, 384):
            ground.alpha_composite(slabs[0 if (tx // 32 + ty // 32) % 2 else 1], (tx, ty))

    trees = load_sprites("trees")
    bushes = load_sprites("bushes")
    rocks = load_sprites("rocks")
    flowers = load_sprites("flowers")
    ruins = load_sprites("ruins")

    def place(sprite, x, y, kind, phase=0.0, sway=2):
        stage.append({"sprite": sprite, "x": x, "y": y, "kind": kind,
                      "phase": phase, "sway": sway,
                      "glow": glow_map(sprite) if kind == "glow_grass" else {}})

    def place_named(store, name, x, y, kind, phase=0.0, sway=2):
        if name not in store:
            print(f"⚠ 场景缺少素材 {name}（已跳过）")
            return
        s = store[name]
        place(s, x - s.width // 2, y - s.height, kind, phase, sway)

    def bottom_center(sprite, x, y):
        return (x - sprite.width // 2, y - sprite.height), None

    # 树木（上半身摆动）
    for name, x, y, ph in (
        ("tree_01", 64, 184, 0.0), ("tree_evolved_01", 172, 166, 0.6),
        ("tree_04", 420, 128, 1.2), ("tree_06", 240, 150, 2.1),
        ("tree_07", 96, 108, 1.7),
    ):
        place_named(trees, name, x, y, "tree", ph)

    # 灌木（整体微摆；带浆果的加脉动）
    for i, (name, x, y) in enumerate((
        ("bush_01", 110, 232), ("bush_03", 200, 240), ("bush_05", 268, 240),
        ("bush_08", 448, 220), ("bush_06", 348, 108), ("bush_02", 30, 158),
        ("bush_07", 140, 92), ("bush_04", 300, 70),
    )):
        place_named(bushes, name, x, y, "glow_grass", i * 0.9, sway=2)

    # 岩石 / 花草
    for name, x, y in (("rock_02", 148, 246), ("rock_07", 316, 240),
                       ("rock_05", 60, 234), ("rock_08", 452, 96),
                       ("rock_03", 210, 84), ("rock_06", 380, 60)):
        place_named(rocks, name, x, y, "static")
    for i, (name, x, y) in enumerate((
        ("flower_05", 92, 250), ("flower_04", 218, 252), ("flower_06", 382, 246),
        ("flower_01", 300, 112), ("flower_05", 428, 206), ("flower_07", 20, 244),
        ("flower_08", 132, 128), ("flower_02", 260, 96), ("flower_03", 60, 110),
    )):
        place_named(flowers, name, x, y, "glow_grass", i * 1.3, sway=1)

    # 遗迹（静止）：断柱移到草地边缘保证可读性
    for name, x, y in (("ruin_01", 272, 206), ("ruin_04", 396, 150),
                       ("ruin_02", 452, 240), ("ruin_evolved_01", 236, 88)):
        place_named(ruins, name, x, y, "static")

    return ground, stage


def render_frame(ground, stage, t):
    frame = ground.copy()
    # 静态层
    for el in stage:
        if el["kind"] == "static":
            frame.alpha_composite(el["sprite"], (el["x"], el["y"]))
    # 摆动层
    for el in stage:
        if el["kind"] == "tree":
            dx = round(math.sin(t / FRAMES * math.pi * 2 + el["phase"]) * 1)
            paste_sway(frame, el["sprite"], (el["x"], el["y"]), dx)
        elif el["kind"] == "glow_grass":
            dx = round(math.sin(t / FRAMES * math.pi * 2 + el["phase"]) * 1)
            s = el["sprite"]
            pulse_on = (t + int(el["phase"] * 3)) % 4 < 2
            img = pulse(s, el["glow"]) if pulse_on else s
            split = 1.0 if s.height < 20 else 0.5
            if s.height < 20:
                frame.alpha_composite(img, (el["x"] + dx, el["y"]))
            else:
                paste_sway(frame, img, (el["x"], el["y"]), dx, split_ratio=0.55)
    # 余烬粒子（演示特效）
    draw_layer = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(draw_layer)
    ember_hi = parse_hex(STYLE["palette"]["ramps"]["ember"][4])
    ember_mid = parse_hex(STYLE["palette"]["ramps"]["ember"][3])
    rng = random.Random(7)
    seeds = [(rng.uniform(40, 440), rng.uniform(60, 250), rng.uniform(0, 6)) for _ in range(9)]
    for i, (bx, by, off) in enumerate(seeds):
        prog = ((t + off * 2) % FRAMES) / FRAMES
        y = by - prog * 70
        x = bx + math.sin(t / 2.5 + i) * 5
        alpha = int(200 * math.sin(prog * math.pi))
        col = ember_hi if (t + i) % 3 else ember_mid
        d.rectangle([x, y, x + 1, y + 1], fill=col + (alpha,))
    frame.alpha_composite(draw_layer)
    return frame


# ---------------------------------------------------------------- GIF

def save_gif(frames_rgba, path, duration=DURATION_MS):
    rgb_frames = [f.convert("RGB") for f in frames_rgba]
    colors = set()
    for f in rgb_frames:
        colors.update(f.getdata())
    colors = list(colors)[:255]
    pal_img = Image.new("P", (1, 1))
    flat = [v for c in colors for v in c]
    flat += [0] * (768 - len(flat))
    pal_img.putpalette(flat)
    pframes = [f.quantize(palette=pal_img, dither=Image.Dither.NONE) for f in rgb_frames]
    pframes[0].save(path, save_all=True, append_images=pframes[1:],
                    duration=duration, loop=0, optimize=False)
    return path


# ---------------------------------------------------------------- 其它素材

def build_variants_gif():
    categories = [
        ("trees", "Trees 树木", 3),
        ("bushes", "Bushes 灌木", 3),
        ("rocks", "Rocks 岩石", 3),
        ("flowers", "Flowers 花草", 3),
        ("tiles", "Terrain 地形", 3),
        ("ruins", "Ruins 遗迹", 2),
    ]
    W, H = 960, 250
    frames = []
    for folder, label, scale in categories:
        img = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(img)
        d.text((24, 14), label if HAS_CJK else label.split(" ")[0],
               fill=(235, 233, 240), font=FONT_26)
        sprites = [s for name, s in sorted(load_sprites(folder).items())]
        sprites = sprites[:9]
        cell_w = (W - 48) // max(1, len(sprites))
        for i, s in enumerate(sprites):
            big = s.resize((s.width * scale, s.height * scale), Image.NEAREST)
            x = 24 + i * cell_w + (cell_w - big.width) // 2
            y = H - 24 - big.height
            img.paste(big, (x, y), big)
        frames.append(img)
    save_gif([f.convert("RGBA") for f in frames], ASSETS / "variants.gif", duration=800)


def build_evolution_png():
    pairs = [
        ("trees", "tree_01", "tree_evolved_01", "阔叶树"),
        ("trees", "tree_04", "tree_evolved_02", "松柏"),
        ("ruins", "ruin_01", "ruin_evolved_01", "断柱"),
        ("ruins", "ruin_04", "ruin_evolved_02", "拱残件"),
    ]
    scale = 3
    panel_w, panel_h = 200, 400
    img = Image.new("RGB", (panel_w * 4, panel_h + 64), BG)
    d = ImageDraw.Draw(img)
    title = "进化前 → 进化后（forge evolve round 2）" if HAS_CJK else \
        "Before -> After (forge evolve round 2)"
    d.text((24, 16), title, fill=(235, 233, 240), font=FONT_26)
    for col, (folder, before, after, label) in enumerate(pairs):
        sprites = load_sprites(folder)
        if before not in sprites or after not in sprites:
            print(f"⚠ 进化对比缺少 {before} 或 {after}（已跳过）")
            continue
        base_x = col * panel_w
        for row, name in enumerate((before, after)):
            s = sprites[name]
            big = s.resize((s.width * scale, s.height * scale), Image.NEAREST)
            x = base_x + (panel_w - big.width) // 2
            y = 64 + row * (panel_h // 2) + (panel_h // 2 - big.height) // 2
            img.paste(big, (x, y), big)
        if HAS_CJK:
            d.text((base_x + 60, 64 + panel_h // 2 - 12), "↓", fill=(201, 106, 51), font=FONT_26)
            d.text((base_x + 70, 72), label, fill=(150, 145, 160), font=FONT_18)
    img.save(ASSETS / "evolution.png")


def main():
    ASSETS.mkdir(exist_ok=True)
    ground, stage = build_scene()

    frames = [render_frame(ground, stage, t) for t in range(FRAMES)]
    big_frames = [f.resize((f.width * SCALE, f.height * SCALE), Image.NEAREST) for f in frames]

    still = big_frames[0]
    still.save(ASSETS / "hero-scene.png")
    save_gif(big_frames, ASSETS / "hero-scene.gif")

    # 供检查的采样胶片（不入库）
    strip = Image.new("RGBA", (big_frames[0].width, big_frames[0].height * 2))
    for i, idx in enumerate((0, 3, 6, 9)):
        strip.alpha_composite(big_frames[idx], (0, (i % 2) * big_frames[0].height))
    strip.resize((strip.width // 2, strip.height // 2), Image.NEAREST).save(
        ASSETS / "_debug_strip.png")

    build_variants_gif()
    build_evolution_png()

    for name in ("hero-scene.gif", "hero-scene.png", "variants.gif", "evolution.png"):
        p = ASSETS / name
        print(f"✓ {p.relative_to(ROOT)}  {p.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
