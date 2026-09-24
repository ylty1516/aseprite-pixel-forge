#!/usr/bin/env python3
"""aseprite-pixel-forge 统一 CLI。

子命令：find-aseprite / style / gen / check / preview / evolve / export / install / doctor
"""

from __future__ import annotations

import argparse
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

# 允许直接以脚本方式运行（python scripts/forge.py）
sys.path.insert(0, str(Path(__file__).resolve().parent))

from aseprite_runner import (  # noqa: E402
    AsepriteNotFound, config_path, find_aseprite, load_config, run_command,
    run_script, save_config,
)
from exporters import export_pngs, export_sheet  # noqa: E402
from quality import (  # noqa: E402
    contact_sheet, mutate_params, png_metrics, save_manifest,
)
from style import (  # noqa: E402
    StyleError, check_png_compliance, export_gpl, load_style, write_style_lua,
)

ROOT = Path(__file__).resolve().parents[1]
GEN_LUA = ROOT / "lua" / "gen.lua"
SCENE_LUA = ROOT / "lua" / "scene.lua"
PX_LUA = ROOT / "lua" / "lib" / "px.lua"
RECIPES = ROOT / "lua" / "recipes"
SKILL_NAME = "aseprite-pixel-forge"

# Windows 重定向/管道下默认 GBK 会吞掉 ✓ 等符号；统一 UTF-8 输出
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass


class ForgeError(RuntimeError):
    """面向用户的友好错误（不打印 traceback）。"""


def _load_manifest_or_die(build):
    p = Path(build) / "manifest.json"
    if not p.is_file():
        raise ForgeError(f"找不到 {p}\n  → 请先运行 forge gen 生成候选（或检查 --out 路径是否正确）")
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ForgeError(f"manifest 损坏，无法解析：{p}\n  {e}") from e


# ---------------------------------------------------------------- 公共

def prepare_style(style_file, workdir: Path):
    style = load_style(style_file)
    workdir.mkdir(parents=True, exist_ok=True)
    style_lua = write_style_lua(style, workdir / f"{style['name']}.lua")
    export_gpl(style, workdir / f"{style['name']}.gpl")
    return style, style_lua


def resolve_recipe(name: str) -> Path:
    p = Path(name)
    if p.suffix == ".lua" and p.is_file():
        return p.resolve()
    for candidate in (RECIPES / f"{name}.lua", RECIPES / "nature" / f"{name}.lua",
                      RECIPES / "debug" / f"{name}.lua"):
        if candidate.is_file():
            return candidate.resolve()
    available = sorted(str(rel.as_posix()) for rel in RECIPES.rglob("*.lua"))
    raise ForgeError(f"未找到配方 {name!r}。可用配方：\n  " + "\n  ".join(available))


def describe_recipe(recipe_path: Path, style_lua: Path, timeout: int = 60) -> dict:
    res = run_script(GEN_LUA, {
        "mode": "describe", "lib": PX_LUA.as_posix(),
        "style": Path(style_lua).as_posix(), "recipe": recipe_path.as_posix(),
    }, timeout=timeout)
    forge = res.get("forge")
    if not forge or not forge.get("ok"):
        raise ForgeError("describe 失败：\n" + res.get("stdout", "") + res.get("stderr", ""))
    return forge["describe"]


def sample_params(specs: dict, rng: random.Random) -> dict:
    # 排序遍历：保证与 describe JSON 键序无关（Lua pairs 顺序随进程随机）
    # sample=false 的参数不采样，取默认值（如 frames/fps，需显式 --param 控制）
    out = {}
    for key, spec in sorted(specs.items()):
        if spec.get("sample") is False:
            out[key] = spec.get("default")
            continue
        t = spec.get("type")
        if t == "int":
            out[key] = rng.randint(int(spec["min"]), int(spec["max"]))
        elif t == "float":
            out[key] = round(rng.uniform(float(spec["min"]), float(spec["max"])), 4)
        elif t == "bool":
            out[key] = rng.random() < 0.5
        elif t == "choice":
            out[key] = rng.choice(list(spec["values"]))
        else:
            out[key] = spec.get("default")
    return out


def coerce_param(spec: dict, raw: str):
    t = spec.get("type")
    if t == "int":
        try:
            return int(float(raw))
        except ValueError:
            raise ValueError(f"期望整数（如 32）") from None
    if t == "float":
        try:
            return float(raw)
        except ValueError:
            raise ValueError(f"期望小数（如 0.5）") from None
    if t == "bool":
        return str(raw).lower() in ("1", "true", "yes", "on")
    if t == "choice":
        values = list(spec.get("values", []))
        if values and raw not in values:
            raise ValueError(f"必须是 {'/'.join(values)} 之一")
        return raw
    return raw


def fmt_params(params: dict) -> str:
    def one(v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, float):
            text = f"{v:.4f}".rstrip("0").rstrip(".")
            return text if text else "0"
        return str(v)

    return ";".join(f"{k}={one(v)}" for k, v in sorted(params.items()))


def parse_indexes(text: str, limit: int) -> list:
    idxs = []
    for piece in str(text).split(","):
        piece = piece.strip()
        if not piece:
            continue
        n = int(piece)
        if n < 1 or n > limit:
            raise ForgeError(f"序号 {n} 超出范围 1..{limit}")
        idxs.append(n)
    if not idxs:
        raise ForgeError("未给出有效序号")
    return idxs


def run_batch(recipe_path: Path, style_lua: Path, style_file: Path, out_dir: Path,
              desc: dict, items: list, round_: int = 1, timeout: int = 120,
              parents: list | None = None,
              extra_script_params: dict | None = None) -> dict:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    cands = []
    total = len(items)
    for i, item in enumerate(items):
        name = f"{desc['name']}_{i + 1:03d}"
        script_params = {
            "mode": "generate", "lib": PX_LUA.as_posix(),
            "style": Path(style_lua).as_posix(), "recipe": recipe_path.as_posix(),
            "seed": item["seed"], "name": name, "out": out.as_posix(),
            "params": fmt_params(item["params"]),
        }
        script_params.update(extra_script_params or {})
        res = run_script(GEN_LUA, script_params, timeout=timeout)
        forge = res.get("forge")
        forge = forge if isinstance(forge, dict) else {}
        error = None
        if not forge.get("ok"):
            if forge.get("error"):
                error = str(forge["error"])
            elif res.get("timeout"):
                error = f"超时（>{timeout}s），进程已终止"
            else:
                detail = (res.get("stderr") or res.get("stdout") or "").strip()
                error = detail[-500:] if detail else f"未知错误（exit={res.get('code')}）"
        files = forge.get("files") or {}
        files = {k: files[k] for k in ("png", "aseprite", "png_frames") if k in files}
        entry = {
            "id": name, "index": i + 1, "seed": item["seed"],
            "params": item["params"], "ok": bool(forge.get("ok")),
            "error": error, "timeout": bool(res.get("timeout")),
            "frames": int(forge.get("frames", 1) or 1),
            "files": files,
            "metrics": None, "selected": False, "score": None,
        }
        cands.append(entry)
        status = "ok" if entry["ok"] else f"FAIL: {entry['error']}"
        print(f"  [{i + 1}/{total}] {name}  {status}")
    manifest = {
        "recipe": desc["name"], "category": desc.get("category"),
        "recipe_path": recipe_path.as_posix(),
        "style": Path(style_file).as_posix(),
        "round": round_, "created": datetime.now().isoformat(timespec="seconds"),
        "parents": parents or [],
        "candidates": cands,
    }
    save_manifest(out, manifest)
    ok_n = sum(1 for c in cands if c["ok"])
    print(f"生成完成：{ok_n}/{total} 成功 → {out / 'manifest.json'}")
    return manifest


# ---------------------------------------------------------------- 子命令

def cmd_find_aseprite(args) -> int:
    if args.set_path:
        p = Path(args.set_path).expanduser()
        if not p.is_file():
            print(f"✗ 文件不存在：{p}")
            return 1
        save_config({**load_config(), "aseprite_path": str(p.resolve())})
        print(f"✓ 已写入配置 {config_path()}\n  aseprite_path = {p.resolve()}")
        return 0
    try:
        p = find_aseprite()
    except AsepriteNotFound as e:
        print(f"✗ {e}")
        return 1
    print(f"✓ Aseprite: {p}")
    ver = run_command([str(p), "--version"])
    if ver["ok"]:
        print("  " + ver["stdout"].strip().splitlines()[0])
    return 0


def cmd_style(args) -> int:
    try:
        if args.style_command == "validate":
            style = load_style(args.style)
            ramps = style["palette"]["ramps"]
            colors = sum(len(r) for r in ramps.values())
            print(f"✓ style 合法：{style['name']}（{len(ramps)} 色阶 / {colors} 色）")
            return 0
        if args.style_command == "gpl":
            style = load_style(args.style)
            out = export_gpl(style, args.out)
            print(f"✓ {out}")
            return 0
        if args.style_command == "lua":
            style = load_style(args.style)
            out = write_style_lua(style, args.out)
            print(f"✓ {out}")
            return 0
    except StyleError as e:
        print(f"✗ {e}")
        return 1
    return 1


def cmd_gen(args) -> int:
    style_file = Path(args.style).resolve()
    out = Path(args.out).resolve()
    workdir = out / "_derived"
    style, style_lua = prepare_style(style_file, workdir)
    recipe_path = resolve_recipe(args.recipe)
    desc = describe_recipe(recipe_path, style_lua)
    specs = desc["params"]

    fixed = {}
    extra_script = {}
    for piece in args.param or []:
        key, _, raw = piece.partition("=")
        if key == "fps":  # 保留脚本参数：直通 Lua（不是配方参数）
            try:
                extra_script["fps"] = int(float(raw))
            except ValueError:
                raise ForgeError(f"参数 fps={raw!r} 非法：期望整数（如 8）") from None
            continue
        if key not in specs:
            raise ForgeError(
                f"未知参数 {key!r}（配方支持：{', '.join(sorted(specs)) or '无'}；另保留 fps）")
        try:
            fixed[key] = coerce_param(specs[key], raw)
        except ValueError as e:
            raise ForgeError(f"参数 {key}={raw!r} 非法：{e}") from e

    items = []
    if args.params_file:
        pf = Path(args.params_file)
        if not pf.is_file():
            raise ForgeError(f"--params-file 不存在：{pf}")
        try:
            spec_json = json.loads(pf.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            raise ForgeError(f"--params-file 解析失败：{e}") from e
        params = {k: spec_json["params"][k] for k in spec_json.get("params", {}) if k in specs}
        params.update(fixed)
        items.append({"params": params, "seed": int(spec_json.get("seed", args.seed))})
    else:
        for i in range(args.count):
            rng = random.Random(args.seed + i)
            params = sample_params(specs, rng)
            params.update(fixed)
            items.append({"params": params, "seed": args.seed + i})

    print(f"配方 {desc['name']}（{desc['category']}），画布 {desc['size'][0]}x{desc['size'][1]}，"
          f"候选 {args.count} 个，seed {args.seed}")
    manifest = run_batch(recipe_path, style_lua, style_file, out, desc, items,
                         timeout=args.timeout, extra_script_params=extra_script)
    ok_n = sum(1 for c in manifest["candidates"] if c["ok"])
    if ok_n == 0:
        print("✗ 全部候选生成失败（详见上方错误与 manifest.json）")
        return 1
    if ok_n < len(items):
        print(f"⚠ {len(items) - ok_n} 个候选失败，可检查 manifest.json 的 error 字段")
    return 0


def cmd_check(args) -> int:
    build = Path(args.build)
    manifest = _load_manifest_or_die(build)
    style_file = Path(args.style).resolve() if args.style else Path(manifest["style"])
    style = load_style(style_file)

    n_bad_palette, n_empty, n_fail = 0, 0, 0
    for c in manifest["candidates"]:
        png = c.get("files", {}).get("png")
        if not c.get("ok") or not png or not Path(png).is_file():
            n_fail += 1
            continue
        c["metrics"] = png_metrics(png, style)
        if not c["metrics"]["palette_ok"]:
            n_bad_palette += 1
        if c["metrics"]["empty"]:
            n_empty += 1
    save_manifest(build, manifest)

    print(f"质检 {manifest['recipe']}：{len(manifest['candidates'])} 候选")
    for c in manifest["candidates"]:
        m = c.get("metrics")
        if not m:
            print(f"  {c['index']:>3} {c['id']}  生成失败")
            continue
        flags = []
        if not m["palette_ok"]:
            flags.append(f"色板违规x{m['palette_bad']}")
        if m["empty"]:
            flags.append("空图")
        if m["edges"]:
            flags.append("触边:" + "/".join(m["edges"]))
        print(f"  {c['index']:>3} {c['id']}  {m['size'][0]}x{m['size'][1]} "
              f"色数={m['colors']} 亮度={m['brightness']}  " + (" ".join(flags) or "OK"))
    print(f"汇总：失败 {n_fail} / 色板违规 {n_bad_palette} / 空图 {n_empty}")
    if args.strict and (n_bad_palette or n_empty or n_fail):
        return 1
    return 0


def cmd_preview(args) -> int:
    build = Path(args.build)
    manifest = _load_manifest_or_die(build)
    cands = [c for c in manifest["candidates"]
             if c.get("ok") and c.get("files", {}).get("png")
             and Path(c["files"]["png"]).is_file()]
    if not cands:
        print("✗ 没有可预览的候选图")
        return 1
    pngs = [c["files"]["png"] for c in cands]
    scale = max(1, args.scale)
    sheet, layout = contact_sheet(pngs, scale=scale, cols=args.cols)
    out_path = Path(args.out) if args.out else build / "preview.png"
    sheet.save(out_path)
    print(f"预览已保存：{out_path}（{scale}x + 1x 并排，共 {len(cands)} 格）")
    for c, lay in zip(cands, layout):
        m = c.get("metrics") or {}
        if m:
            note = "色板OK" if m["palette_ok"] else f"色板违规x{m['palette_bad']}"
            note += f", 色数{m['colors']}, 亮度{m['brightness']}"
        else:
            note = "未质检"
        print(f"  {lay['index']:>3} = {c['id']}  [{note}, seed={c['seed']}]")
    return 0


def cmd_evolve(args) -> int:
    parent_dir = Path(args.build)
    parent_manifest = _load_manifest_or_die(parent_dir)
    parents_all = parent_manifest["candidates"]
    keep = parse_indexes(args.keep, len(parents_all))
    for idx in keep:
        if not parents_all[idx - 1].get("ok"):
            raise ForgeError(f"父本 {idx} 生成失败，不能进化")
    # 标记父本为已选用（写入父轮 manifest，落实 selected 契约）
    for idx in keep:
        parents_all[idx - 1]["selected"] = True
    save_manifest(parent_dir, parent_manifest)

    style_file = Path(parent_manifest["style"]).resolve()
    out = Path(args.out).resolve()
    style, style_lua = prepare_style(style_file, out / "_derived")
    recipe_path = Path(parent_manifest["recipe_path"])
    desc = describe_recipe(recipe_path, style_lua)

    round_ = parent_manifest.get("round", 1) + 1
    items, parent_ids = [], []
    for i, idx in enumerate(keep):
        parent = parents_all[idx - 1]
        rng = random.Random(parent["seed"] * 7919 + round_ * 13 + i)
        params = mutate_params(parent["params"], desc["params"], rng, jitter=args.jitter)
        items.append({"params": params, "seed": parent["seed"] + 777 * round_ + i})
        parent_ids.append(parent["id"])
    print(f"进化第 {round_} 轮：保留 {parent_ids} → {len(items)} 个新候选")
    run_batch(recipe_path, style_lua, style_file, out, desc, items,
              round_=round_, timeout=args.timeout, parents=parent_ids)
    return 0


def cmd_export(args) -> int:
    build = Path(args.build)
    manifest = _load_manifest_or_die(build)
    cands_all = manifest["candidates"]
    prefix = args.prefix or manifest["recipe"]
    style_file = Path(args.style).resolve() if args.style else Path(manifest["style"])
    style = load_style(style_file)

    if args.pick:
        picks = [cands_all[i - 1] for i in parse_indexes(args.pick, len(cands_all))]
    else:
        picks = [c for c in cands_all if c.get("ok")]

    problems = []
    for c in picks:
        png = c.get("files", {}).get("png")
        if not c.get("ok") or not png or not Path(png).is_file():
            problems.append(f"{c['id']} 生成失败")
            continue
        # 总是重算指标（避免旧 style/旧 run 的陈旧判定）
        c["metrics"] = png_metrics(png, style)
        if not c["metrics"]["palette_ok"]:
            problems.append(f"{c['id']} 色板违规x{c['metrics']['palette_bad']}")
        elif c["metrics"]["empty"]:
            problems.append(f"{c['id']} 空图")
    if problems and not args.force:
        print("✗ 导出被拒绝（色板纪律/空图）：")
        for p in problems:
            print("   -", p)
        print("  修复配方后重跑，或 --force 强行导出。")
        return 1

    # 标记导出项为已选用（写入 manifest，落实 selected 契约）
    for c in picks:
        c["selected"] = True
    save_manifest(build, manifest)

    out = Path(args.out)
    png_paths = [c["files"]["png"] for c in picks if c.get("files", {}).get("png")]
    exported = export_pngs(png_paths, out, prefix=prefix)

    src_dir = out / "source_aseprite"
    src_dir.mkdir(parents=True, exist_ok=True)
    exported_sources = []
    for c in picks:
        ase = c.get("files", {}).get("aseprite")
        if ase and Path(ase).is_file():
            shutil.copyfile(ase, src_dir / Path(ase).name)
            exported_sources.append(Path(ase).name)

    sheet_info = None
    if args.sheet and exported:
        sheet_info = export_sheet(
            [str(p) for p in exported], out / f"{prefix}_sheet.png",
            out / f"{prefix}_sheet.json", columns=args.sheet_cols)

    # 多帧候选：经 Aseprite 导出动画 GIF
    gif_exported = []
    if args.gif and exported:
        asp = find_aseprite()
        for i, c in enumerate(picks, start=1):
            ase = c.get("files", {}).get("aseprite")
            if not ase or not Path(ase).is_file() or int(c.get("frames", 1) or 1) <= 1:
                continue
            gif_path = out / f"{prefix}_{i:02d}.gif"
            res = run_command([str(asp), "-b", str(ase), "--save-as", str(gif_path)])
            if res["ok"] and gif_path.is_file():
                gif_exported.append(gif_path.name)
            else:
                print(f"⚠ GIF 导出失败：{c['id']}  {str(res.get('stderr', ''))[-160:]}")

    pack = {
        "recipe": manifest["recipe"],
        "prefix": prefix,
        "style": style["name"],
        "exported": [str(p.name) for p in exported],
        "sources": sorted(exported_sources),
        "sheet": {"png": sheet_info[0].name, "json": sheet_info[1].name} if sheet_info else None,
        "gif": gif_exported,
        "candidates": [
            {"id": c["id"], "seed": c["seed"], "params": c["params"],
             "metrics": c.get("metrics")}
            for c in picks
        ],
    }
    pack_path = out / "pack.json"
    if pack_path.exists():
        try:
            existing = json.loads(pack_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            existing = None
        if isinstance(existing, dict) and existing.get("prefix") not in (None, prefix):
            pack_path = out / f"pack_{prefix}.json"
    pack_path.write_text(
        json.dumps(pack, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"✓ 已导出 {len(exported)} 图 → {out}")
    if sheet_info:
        print(f"✓ 图集：{sheet_info[0]} + {sheet_info[1]}")
    if gif_exported:
        print(f"✓ 动图：{len(gif_exported)} 个 GIF")
    print(f"✓ 清单：{pack_path}")
    return 0


def cmd_scene(args) -> int:
    scene_file = Path(args.scene).resolve()
    if not scene_file.is_file():
        raise ForgeError(f"场景谱不存在：{scene_file}")
    out = Path(args.out).resolve()
    style_file = (Path(args.style).resolve() if args.style
                  else ROOT / "styles" / "left-hand-of-god.json")
    style, style_lua = prepare_style(style_file, out / "_derived")
    out.mkdir(parents=True, exist_ok=True)
    pack_dir = (Path(args.pack).resolve() if args.pack
                else ROOT / "examples" / "gothic-nature-pack")

    params = {
        "lib": PX_LUA.as_posix(), "style": style_lua.as_posix(),
        "scene": scene_file.as_posix(), "out": out.as_posix(),
        "pack": pack_dir.as_posix(),
    }
    if args.frames:
        params["frames"] = args.frames
    if args.fps:
        params["fps"] = args.fps
    if args.time:
        params["time"] = args.time
    if args.size:
        params["size"] = args.size

    print(f"场景 {scene_file.name} 渲染中（帧数 {args.frames or '默认'}，超时 {args.timeout}s）...")
    res = run_script(SCENE_LUA, params, timeout=args.timeout)
    forge = res.get("forge")
    if not forge or not forge.get("ok"):
        detail = forge.get("error") if forge else (res.get("stderr") or res.get("stdout"))
        print(f"✗ 场景渲染失败：{str(detail)[-500:]}")
        return 1

    frames = int(forge.get("frames", 1) or 1)
    frame_pngs = forge.get("files", {}).get("png_frames") or []
    bad_total = 0
    for png in frame_pngs:
        rep = check_png_compliance(png, style)
        bad_total += rep["bad"]
        if not rep["ok"]:
            print(f"⚠ {Path(png).name} 色板违规 x{rep['bad']}：{rep['bad_colors'][:4]}")
    size = forge.get("size") or [0, 0]
    print(f"✓ 场景渲染完成：{forge.get('name')}  {size[0]}x{size[1]}  {frames} 帧")
    print(f"  帧序列：{Path(frame_pngs[0]).parent if frame_pngs else out}")
    print(f"  色板合规：{'100%' if bad_total == 0 else f'{bad_total} 个违规像素'}")
    if bad_total:
        return 1

    if args.gif and frames > 1:
        asp = find_aseprite()
        ase = forge.get("files", {}).get("aseprite")
        gif_path = out / f"{forge.get('name')}.gif"
        rr = run_command([str(asp), "-b", str(ase), "--save-as", str(gif_path)])
        if rr["ok"] and gif_path.is_file():
            print(f"✓ 动图：{gif_path.relative_to(Path.cwd()) if str(gif_path).startswith(str(Path.cwd())) else gif_path}")
        else:
            print(f"⚠ GIF 导出失败：{str(rr.get('stderr', ''))[-160:]}")
            return 1
    return 0


def cmd_install(args) -> int:
    target = (Path(args.target).expanduser() if args.target
              else Path.home() / ".agents" / "skills" / SKILL_NAME)
    if target.exists():
        if not args.force:
            print(f"✗ 目标已存在：{target}\n  使用 --force 覆盖。")
            return 1
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    if args.link and os.name == "nt":
        r = subprocess.run(["cmd", "/c", "mklink", "/J", str(target), str(ROOT)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print(f"✗ junction 创建失败：{r.stdout}{r.stderr}")
            return 1
        print(f"✓ 已 junction 安装（开发模式，改动即时生效）→ {target}")
    else:
        ignore = shutil.ignore_patterns(
            ".git", "__pycache__", ".pytest_cache", "forge-build", "*.pyc",
            "docs")
        shutil.copytree(ROOT, target, ignore=ignore)
        print(f"✓ 已复制安装 → {target}")
        print(f"  更新方式：重跑 forge.py install --force")
    print(f"  通用发现路径：~/.agents/skills/（pi / Claude Code / 其他 Agent Skills 兼容 agent）")
    return 0


def cmd_doctor(args) -> int:
    ok = True
    print("aseprite-pixel-forge doctor")
    print("-" * 40)

    try:
        asp = find_aseprite()
        ver = run_command([str(asp), "--version"])
        vtext = ver["stdout"].strip().splitlines()[0] if ver["ok"] else "版本未知"
        print(f"✓ Aseprite: {asp}\n  {vtext}")
    except AsepriteNotFound as e:
        print(f"✗ Aseprite 未找到\n{e}")
        ok = False

    try:
        import PIL  # noqa: F401
        print(f"✓ Python {sys.version.split()[0]} + Pillow")
    except ImportError as e:
        print(f"✗ Pillow 缺失: {e}")
        ok = False

    try:
        style = load_style(ROOT / "styles" / "left-hand-of-god.json")
        print(f"✓ 基准 style：{style['name']}（{len(style['palette']['ramps'])} 色阶）")
    except StyleError as e:
        print(f"✗ style 校验失败: {e}")
        ok = False

    if ok:
        try:
            with tempfile.TemporaryDirectory() as td:
                td = Path(td)
                style, style_lua = prepare_style(
                    ROOT / "styles" / "left-hand-of-god.json", td / "derived")
                recipe = resolve_recipe("smoke")
                desc = describe_recipe(recipe, style_lua)
                print(f"✓ 配方冒烟：{desc['name']} {desc['size'][0]}x{desc['size'][1]}")
                run_batch(recipe, style_lua, ROOT / "styles" / "left-hand-of-god.json",
                          td / "out", desc, [{"params": sample_params(
                              desc["params"], random.Random(1)), "seed": 1}])
                m = png_metrics(td / "out" / "smoke_001.png", style)
                if m["palette_ok"] and not m["empty"]:
                    print(f"✓ 端到端冒烟通过（色数 {m['colors']}，亮度 {m['brightness']}）")
                else:
                    print(f"✗ 冒烟图异常：{m}")
                    ok = False
        except (ForgeError, SystemExit) as e:
            print(f"✗ 冒烟失败: {e}")
            ok = False

    print("-" * 40)
    print("✓ doctor 全部通过" if ok else "✗ doctor 存在失败项")
    return 0 if ok else 1


# ---------------------------------------------------------------- main

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="forge", description="aseprite-pixel-forge 工具集")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("find-aseprite", help="定位/配置 Aseprite")
    p.add_argument("--set", dest="set_path", help="写入配置：Aseprite 可执行文件路径")
    p.set_defaults(func=cmd_find_aseprite)

    p = sub.add_parser("style", help="style spec 工具")
    ssub = p.add_subparsers(dest="style_command", required=True)
    v = ssub.add_parser("validate"); v.add_argument("style")
    g = ssub.add_parser("gpl"); g.add_argument("style"); g.add_argument("out")
    l = ssub.add_parser("lua"); l.add_argument("style"); l.add_argument("out")
    p.set_defaults(func=cmd_style)

    p = sub.add_parser("gen", help="批量生成候选")
    p.add_argument("recipe")
    p.add_argument("--style", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--count", type=int, default=24)
    p.add_argument("--seed", type=int, default=1000)
    p.add_argument("--param", action="append", default=[], help="固定参数 k=v（可多次）")
    p.add_argument("--params-file", help="JSON {seed, params}：精确复现/重生成单候选（与 --param 可叠加覆盖）")
    p.add_argument("--timeout", type=int, default=120)
    p.set_defaults(func=cmd_gen)

    p = sub.add_parser("check", help="数值质检")
    p.add_argument("build")
    p.add_argument("--style")
    p.add_argument("--strict", action="store_true")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("preview", help="放大预览 + 编号联系表")
    p.add_argument("build")
    p.add_argument("--out")
    p.add_argument("--scale", type=int, default=6)
    p.add_argument("--cols", type=int, default=6)
    p.set_defaults(func=cmd_preview)

    p = sub.add_parser("evolve", help="按保留序号进化出新候选")
    p.add_argument("build")
    p.add_argument("--keep", required=True, help="候选序号（预览中的编号），如 1,5,9")
    p.add_argument("--out", required=True)
    p.add_argument("--jitter", type=float, default=0.25)
    p.add_argument("--timeout", type=int, default=120)
    p.set_defaults(func=cmd_evolve)

    p = sub.add_parser("export", help="导出成品（单图/图集）")
    p.add_argument("build")
    p.add_argument("--out", required=True)
    p.add_argument("--pick", default="", help="候选序号，如 1,5,9；缺省=全部成功候选")
    p.add_argument("--prefix", help="导出文件前缀（默认=配方名）")
    p.add_argument("--sheet", action="store_true")
    p.add_argument("--sheet-cols", type=int, default=8)
    p.add_argument("--gif", action="store_true", help="多帧候选额外导出动画 GIF")
    p.add_argument("--style")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=cmd_export)

    p = sub.add_parser("scene", help="场景渲染（大气光影/视差/叙事构图）")
    p.add_argument("scene", help="场景谱路径（scenes/*.lua）")
    p.add_argument("--out", required=True)
    p.add_argument("--style")
    p.add_argument("--pack", help="素材包目录（默认 examples/gothic-nature-pack）")
    p.add_argument("--frames", type=int)
    p.add_argument("--fps", type=int)
    p.add_argument("--time", help="调色预设（day/dawn/dusk/night/bloodmoon...）")
    p.add_argument("--size", help="覆盖画布尺寸 WxH（测试用小尺寸）")
    p.add_argument("--gif", action="store_true")
    p.add_argument("--timeout", type=int, default=600)
    p.set_defaults(func=cmd_scene)

    p = sub.add_parser("install", help="安装为全局 skill")
    p.add_argument("--target")
    p.add_argument("--force", action="store_true")
    p.add_argument("--link", action="store_true", help="Windows junction（开发模式）")
    p.set_defaults(func=cmd_install)

    p = sub.add_parser("doctor", help="环境自检 + 端到端冒烟")
    p.set_defaults(func=cmd_doctor)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except StyleError as e:
        print(f"✗ {e}")
        return 1
    except AsepriteNotFound as e:
        print(f"✗ {e}")
        return 1
    except ForgeError as e:
        print(f"✗ {e}")
        return 1
    except KeyboardInterrupt:
        print("\n已取消。")
        return 130


if __name__ == "__main__":
    sys.exit(main())
