#!/usr/bin/env python3
"""构建 README 演示素材（v2：配方原生多帧动画版）。

产出（assets/）：
  hero-scene.gif   960x540 场景动效（2x），12 帧 —— 树木/灌木/花草均为配方原生帧动画
  hero-scene.png   静止首帧
  tree-sway.gif    单株树木摆动（6 帧动画，6x 放大）
  variants.gif     六品类变体轮播
  evolution.png    进化前后对比

动画说明：植物动画本体由配方原生多帧生成（frames 参数；树冠相位摆动/团簇呼吸/
叶片剪切弯曲），帧序列经 Aseprite 保存；场景中的火星粒子与浆果脉动为演示点缀。

用法： py -3 tools/make_showcase.py [--no-regen]   （--no-regen 复用已生成缓存）
"""

from __future__ import annotations

import argparse
import json
import math
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "examples" / "gothic-nature-pack"
ASSETS = ROOT / "assets"
CACHE = ROOT / "forge-build" / "showcase"
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
FRAMES = 12          # 场景循环帧数
DURATION_MS = 90
SPRITE_FRAMES = 4    # 场景内动画素材帧数（12 % 4 == 0 保证无缝循环）

FOLDER_RECIPE = {"trees": "tree", "bushes": "bush", "rocks": "rock",
                 "flowers": "flower", "tiles": "tile", "ruins": "ruin"}
SCENE = ROOT / "scenes" / "bloodmoon-ruins.lua"


# ---------------------------------------------------------------- 字体 / 载入

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
    return {parse_hex(c) + (255,): i + 1
            for i, c in enumerate(STYLE["palette"]["ramps"][ramp_name])}


EMBER = palette_levels("ember")
FROST = palette_levels("frost")


def glow_map(sprite: Image.Image) -> dict:
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


# ---------------------------------------------------------------- 动画素材重生成

def build_cast_index(folder: str) -> dict:
    """{导出名: {seed, params}}，含进化轮 pack_*.json。"""
    idx = {}
    main = PACK / folder / "pack.json"
    files = [main] + sorted((PACK / folder).glob("pack_*.json"))
    for f in files:
        if not f.is_file():
            continue
        data = json.loads(f.read_text(encoding="utf-8"))
        prefix = data.get("prefix", data.get("recipe", "sprite"))
        for i, c in enumerate(data.get("candidates", []), 1):
            idx[f"{prefix}_{i:02d}"] = {"seed": c["seed"], "params": c["params"]}
    return idx


def regenerate_animated(folder: str, name: str, frames: int = SPRITE_FRAMES,
                        fps: int = 8, use_cache: bool = True) -> list:
    """按 pack.json 记录的 seed/params 重生成带帧动画的候选；返回帧图列表。"""
    cache = CACHE / f"{folder}-{name}-f{frames}"
    if use_cache and cache.is_dir() and list(cache.glob("*_f2.png")):
        pass
    else:
        idx = build_cast_index(folder)
        if name not in idx:
            print(f"⚠ 演算索引缺少 {folder}/{name}（用静态图代替）")
            return []
        cache.mkdir(parents=True, exist_ok=True)
        pf = cache / "params.json"
        pf.write_text(json.dumps(idx[name], ensure_ascii=False), encoding="utf-8")
        recipe = FOLDER_RECIPE[folder]
        r = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "forge.py"), "gen", recipe,
             "--style", str(ROOT / "styles" / "left-hand-of-god.json"),
             "--out", str(cache), "--params-file", str(pf),
             "--param", f"frames={frames}", "--param", f"fps={fps}"],
            capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode != 0:
            print(f"⚠ 动画重生成失败 {name}: {r.stdout[-200:]}{r.stderr[-200:]}")
            return []
    base = sorted(p for p in cache.glob("*.png") if "_f" not in p.stem
                  and not p.name.startswith("_"))
    if not base:
        return []
    stem = base[0].stem
    frames_list = [cache / f"{stem}.png"]
    i = 2
    while (f_ := cache / f"{stem}_f{i}.png").is_file():
        frames_list.append(f_)
        i += 1
    return [Image.open(p).convert("RGBA") for p in frames_list]


# ---------------------------------------------------------------- 场景

ANIMATED = {
    "trees": ["tree_01", "tree_evolved_01", "tree_04", "tree_07"],
    "bushes": ["bush_01", "bush_03", "bush_05", "bush_06", "bush_07", "bush_08"],
    "flowers": ["flower_01", "flower_03", "flower_04", "flower_05", "flower_06", "flower_08"],
}


def build_scene(use_cache: bool = True):
    rng = random.Random(20260923)
    tiles = load_sprites("tiles")
    stage = []

    ground = Image.new("RGBA", (GAME_W, GAME_H), BG + (255,))
    grass_tiles = [tiles[k] for k in ("tile_02", "grass_01", "grass_02") if k in tiles]
    for ty in range(0, GAME_H, 32):
        for tx in range(0, GAME_W, 32):
            tile = grass_tiles[rng.randrange(len(grass_tiles))]
            if rng.random() < 0.5:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            ground.alpha_composite(tile, (tx, ty))

    dirt_tiles = [tiles[k] for k in ("tile_01", "tile_05") if k in tiles]
    for tx in range(-32, GAME_W + 32, 32):
        wy = int(196 - math.sin(tx / 110.0) * 26)
        ground.alpha_composite(dirt_tiles[(tx // 32) % 2], (tx, wy))
        ground.alpha_composite(dirt_tiles[(tx // 32) % 2], (tx, wy + 32))

    cobble = [tiles[k] for k in ("tile_03", "tile_07") if k in tiles]
    for ty in range(128, 256, 32):
        for tx in range(288, GAME_W, 32):
            ground.alpha_composite(cobble[rng.randrange(len(cobble))], (tx, ty))
    slabs = [tiles[k] for k in ("tile_04", "tile_06") if k in tiles]
    for ty in (160, 192):
        for tx in (320, 352, 384):
            ground.alpha_composite(slabs[0 if (tx // 32 + ty // 32) % 2 else 1], (tx, ty))

    stores = {f: load_sprites(f) for f in
              ("trees", "bushes", "rocks", "flowers", "ruins")}
    anim_frames = {}
    for folder, names in ANIMATED.items():
        for name in names:
            fl = regenerate_animated(folder, name, use_cache=use_cache)
            if fl:
                anim_frames[(folder, name)] = fl
            else:
                print(f"ℹ {folder}/{name} 使用静态帧")

    def get_frames(folder, name):
        fl = anim_frames.get((folder, name))
        if fl:
            return fl
        s = stores[folder].get(name)
        return [s] if s else [None]

    def place(folder, name, x, y, kind="static", phase=0):
        fl = get_frames(folder, name)
        if fl[0] is None:
            print(f"⚠ 场景缺少素材 {folder}/{name}")
            return
        s = fl[0]
        stage.append({
            "frames": fl, "kind": kind, "phase": phase,
            "x": x - s.width // 2, "y": y - s.height,
            "glow": glow_map(s) if kind == "glow" else {},
        })

    # 树木
    place("trees", "tree_01", 64, 184, "anim", 0)
    place("trees", "tree_evolved_01", 172, 166, "anim", 1)
    place("trees", "tree_04", 420, 128, "anim", 2)
    place("trees", "tree_06", 240, 150)          # 枯树：静态
    place("trees", "tree_07", 96, 108, "anim", 3)
    # 灌木
    for i, (name, x, y) in enumerate((
        ("bush_01", 110, 232), ("bush_03", 200, 240), ("bush_05", 268, 240),
        ("bush_08", 448, 220), ("bush_06", 348, 108), ("bush_02", 30, 158),
        ("bush_07", 140, 92), ("bush_04", 300, 70),
    )):
        place("bushes", name, x, y, "glow", i)
    # 岩石
    for name, x, y in (("rock_02", 148, 246), ("rock_07", 316, 240),
                       ("rock_05", 60, 234), ("rock_08", 452, 96),
                       ("rock_03", 210, 84), ("rock_06", 380, 60)):
        place("rocks", name, x, y)
    # 花草
    for i, (name, x, y) in enumerate((
        ("flower_05", 92, 250), ("flower_04", 218, 252), ("flower_06", 382, 246),
        ("flower_01", 300, 112), ("flower_05", 428, 206), ("flower_07", 20, 244),
        ("flower_08", 132, 128), ("flower_02", 260, 96), ("flower_03", 60, 110),
    )):
        place("flowers", name, x, y, "glow", i * 2)
    # 遗迹（静态）
    for name, x, y in (("ruin_01", 272, 206), ("ruin_04", 396, 150),
                       ("ruin_02", 452, 240), ("ruin_evolved_01", 236, 88)):
        place("ruins", name, x, y)

    return ground, stage


def render_frame(ground, stage, t):
    frame = ground.copy()
    for el in stage:
        fl = el["frames"]
        n = len(fl)
        if el["kind"] == "static" or n == 1:
            img = fl[0]
        else:
            step = max(1, FRAMES // n)
            idx = ((t // step) + el["phase"]) % n
            img = fl[idx]
            if el["kind"] == "glow":
                img = pulse(img, el["glow"]) if (t % 4 < 2) else img
        frame.alpha_composite(img, (el["x"], el["y"]))

    # 余烬粒子（演示点缀）
    layer = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ember_hi = parse_hex(STYLE["palette"]["ramps"]["ember"][4])
    ember_mid = parse_hex(STYLE["palette"]["ramps"]["ember"][3])
    rng = random.Random(7)
    seeds = [(rng.uniform(40, 440), rng.uniform(60, 250), rng.uniform(0, 6)) for _ in range(9)]
    for i, (bx, by, off) in enumerate(seeds):
        prog = ((t + off * 2) % FRAMES) / FRAMES
        y = by - prog * 70
        x = bx + math.sin(t / 2.5 + i) * 5
        alpha = int(190 * math.sin(prog * math.pi))
        col = ember_hi if (t + i) % 3 else ember_mid
        d.rectangle([x, y, x + 1, y + 1], fill=col + (alpha,))
    frame.alpha_composite(layer)
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

def build_tree_sway(use_cache=True):
    fl = regenerate_animated("trees", "tree_evolved_01", frames=6, fps=6,
                             use_cache=use_cache)
    if not fl:
        return
    s = 6
    big = [f.resize((f.width * s, f.height * s), Image.NEAREST) for f in fl]
    W, H = big[0].size
    canvas = [Image.new("RGBA", (W + 80, H + 60), BG + (255,)) for _ in big]
    for i, b in enumerate(big):
        canvas[i].alpha_composite(b, (40, 20))
    save_gif(canvas, ASSETS / "tree-sway.gif", duration=150)


def build_keyart(use_cache: bool = True):
    """血月废墟 keynote 动画 + 昼夜调色对比（forge scene）。"""

    def run_scene(out: Path, time=None, frames=8, make_gif=False):
        if use_cache and (out / "bloodmoon-ruins.aseprite").is_file():
            return out
        args = [sys.executable, str(ROOT / "scripts" / "forge.py"), "scene",
                str(SCENE), "--out", str(out), "--frames", str(frames)]
        if time:
            args += ["--time", time]
        if make_gif:
            args += ["--gif"]
        r = subprocess.run(args, capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        if r.returncode != 0:
            print(f"⚠ 场景渲染失败（{time or 'bloodmoon'}）：{r.stdout[-200:]}")
            return None
        return out

    # 1) 血月 keynote（8 帧动画）
    out = run_scene(CACHE / "keyart-bloodmoon", frames=8, make_gif=True)
    if out and (out / "bloodmoon-ruins.gif").is_file():
        import shutil as _sh
        _sh.copyfile(out / "bloodmoon-ruins.gif", ASSETS / "keyart-bloodmoon.gif")

    # 2) 昼夜时段对比
    times = ["day", "dawn", "dusk", "night", "bloodmoon"]
    labels = ["Day 白昼", "Dawn 黎明", "Dusk 黄昏", "Night 深夜", "Bloodmoon 血月"]
    imgs = []
    for t in times:
        o = run_scene(CACHE / f"daynight-{t}", time=t, frames=1)
        p = o / "bloodmoon-ruins.png" if o else None
        imgs.append(Image.open(p).convert("RGB") if p and p.is_file() else None)
    if all(imgs):
        save_gif([im.convert("RGBA") for im in imgs], ASSETS / "daynight.gif",
                 duration=750)
        sc = 0.5
        w, h = imgs[0].size
        sw, sh = int(w * sc), int(h * sc)
        lab_h = 26
        strip = Image.new("RGB", (sw * len(times), sh + lab_h), BG)
        d = ImageDraw.Draw(strip)
        for i, (im, lab) in enumerate(zip(imgs, labels)):
            strip.paste(im.resize((sw, sh), Image.LANCZOS), (i * sw, lab_h))
        if HAS_CJK:
            for i, lab in enumerate(labels):
                d.text((i * sw + 8, 3), lab, fill=(235, 233, 240), font=FONT_18)
        strip.save(ASSETS / "daynight.png")


def build_variants_gif():
    categories = [
        ("trees", "Trees 树木", 3), ("bushes", "Bushes 灌木", 3),
        ("rocks", "Rocks 岩石", 3), ("flowers", "Flowers 花草", 3),
        ("tiles", "Terrain 地形", 3), ("ruins", "Ruins 遗迹", 2),
    ]
    W, H = 960, 250
    frames = []
    for folder, label, scale in categories:
        img = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(img)
        d.text((24, 14), label if HAS_CJK else label.split(" ")[0],
               fill=(235, 233, 240), font=FONT_26)
        sprites = [s for _, s in sorted(load_sprites(folder).items())][:9]
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
            d.text((base_x + 60, 64 + panel_h // 2 - 12), "↓",
                   fill=(201, 106, 51), font=FONT_26)
            d.text((base_x + 70, 72), label, fill=(150, 145, 160), font=FONT_18)
    img.save(ASSETS / "evolution.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-regen", action="store_true", help="复用已生成的动画缓存")
    args = ap.parse_args()
    use_cache = args.no_regen

    ASSETS.mkdir(exist_ok=True)
    ground, stage = build_scene(use_cache=use_cache)

    frames = [render_frame(ground, stage, t) for t in range(FRAMES)]
    big = [f.resize((f.width * SCALE, f.height * SCALE), Image.NEAREST) for f in frames]

    big[0].save(ASSETS / "hero-scene.png")
    save_gif(big, ASSETS / "hero-scene.gif")

    # 采样胶片（仅本地检查用，写入 forge-build 不入库）
    strip = Image.new("RGBA", (big[0].width, big[0].height * 2))
    for i, idx in enumerate((0, 3, 6, 9)):
        strip.alpha_composite(big[idx], (0, (i % 2) * big[0].height))
    debug_dir = ROOT / "forge-build"
    debug_dir.mkdir(exist_ok=True)
    strip.resize((strip.width // 2, strip.height // 2), Image.NEAREST).save(
        debug_dir / "showcase-strip.png")

    build_tree_sway(use_cache=use_cache)
    build_keyart(use_cache=use_cache)
    build_variants_gif()
    build_evolution_png()

    for name in ("hero-scene.gif", "hero-scene.png", "tree-sway.gif",
                 "keyart-bloodmoon.gif", "daynight.gif", "daynight.png",
                 "variants.gif", "evolution.png"):
        p = ASSETS / name
        if p.is_file():
            print(f"✓ {p.relative_to(ROOT)}  {p.stat().st_size // 1024} KB")
        else:
            print(f"⚠ {p.relative_to(ROOT)} 未生成")


if __name__ == "__main__":
    main()
