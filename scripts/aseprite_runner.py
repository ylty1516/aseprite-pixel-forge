"""Aseprite 定位与无头执行封装。

协议：aseprite -b --script <script.lua> --script-param k=v ...
Lua 侧在 stdout 打印 ``FORGE:{...}`` 单行 JSON 作为结构化结果。
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

DEFAULT_TIMEOUT = 120


class AsepriteNotFound(RuntimeError):
    pass


# ---------------------------------------------------------------- 配置

def config_path() -> Path:
    env = os.environ.get("ASEPRITE_FORGE_CONFIG")
    if env:
        return Path(env)
    return Path.home() / ".aseprite-pixel-forge" / "config.json"


def load_config() -> dict:
    p = config_path()
    if p.is_file():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}
    return {}


def save_config(cfg: dict) -> Path:
    p = config_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")
    return p


# ---------------------------------------------------------------- 定位

def _candidate_paths():
    """跨平台常见安装路径（按平台习惯排列）。"""
    if os.name == "nt":
        env = os.environ
        for root in (env.get("ProgramFiles"), env.get("ProgramFiles(x86)")):
            if root:
                yield Path(root) / "Aseprite" / "Aseprite.exe"
                yield Path(root) / "Steam" / "steamapps" / "common" / "Aseprite" / "Aseprite.exe"
        for drive in ("C:", "D:", "E:", "F:", "G:"):
            yield Path(f"{drive}/SteamLibrary/steamapps/common/Aseprite/Aseprite.exe")
            yield Path(f"{drive}/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe")
        yield Path.home() / "scoop/apps/aseprite/current/Aseprite.exe"
    else:
        yield Path("/Applications/Aseprite.app/Contents/MacOS/aseprite")
        yield Path.home() / ".steam/steam/steamapps/common/Aseprite/aseprite"
        yield Path.home() / ".local/share/Steam/steamapps/common/Aseprite/aseprite"
        yield Path("/usr/bin/aseprite")
        yield Path("/usr/local/bin/aseprite")
        yield Path("/snap/bin/aseprite")


def find_aseprite() -> Path:
    """优先级：ASEPRITE_PATH 环境变量 → 用户配置 → PATH → 常见路径。"""
    env = os.environ.get("ASEPRITE_PATH")
    if env and Path(env).is_file():
        return Path(env)

    cfg_path = load_config().get("aseprite_path")
    if cfg_path and Path(cfg_path).is_file():
        return Path(cfg_path)

    for name in ("aseprite", "Aseprite", "aseprite.exe"):
        which = shutil.which(name)
        if which:
            return Path(which)

    for cand in _candidate_paths():
        if cand.is_file():
            return cand

    raise AsepriteNotFound(
        "未找到 Aseprite。请任选一种方式：\n"
        "  1) 设置环境变量 ASEPRITE_PATH 指向可执行文件\n"
        "  2) 运行：python scripts/forge.py find-aseprite --set <Aseprite 可执行文件路径>\n"
        "  3) 把 Aseprite 加入系统 PATH"
    )


# ---------------------------------------------------------------- 执行

def build_args(aseprite: Path, script: Path, params: dict | None = None,
               extra: list | None = None) -> list:
    args = [str(aseprite), "-b", "--script", str(script)]
    for key, value in (params or {}).items():
        args += ["--script-param", f"{key}={value}"]
    if extra:
        args += [str(x) for x in extra]
    return args


def parse_forge(stdout: str):
    for line in stdout.splitlines():
        line = line.strip()
        if line.startswith("FORGE:"):
            try:
                return json.loads(line[len("FORGE:"):])
            except json.JSONDecodeError:
                continue
    return None


def run_command(args: list, timeout: int = DEFAULT_TIMEOUT) -> dict:
    try:
        proc = subprocess.run(args, capture_output=True, timeout=timeout)
        return {
            "ok": proc.returncode == 0,
            "code": proc.returncode,
            "stdout": proc.stdout.decode("utf-8", "replace"),
            "stderr": proc.stderr.decode("utf-8", "replace"),
            "timeout": False,
        }
    except subprocess.TimeoutExpired as e:
        return {
            "ok": False, "code": None,
            "stdout": (e.stdout or b"").decode("utf-8", "replace"),
            "stderr": (e.stderr or b"").decode("utf-8", "replace"),
            "timeout": True,
        }
    except OSError as e:
        return {"ok": False, "code": None, "stdout": "", "stderr": str(e), "timeout": False}


def run_script(script, params: dict | None = None, timeout: int = DEFAULT_TIMEOUT,
               aseprite=None, extra: list | None = None) -> dict:
    """运行 Lua 脚本；返回 {ok, code, stdout, stderr, timeout, forge}。"""
    asp = Path(aseprite) if aseprite else find_aseprite()
    args = build_args(asp, Path(script), params or {}, extra)
    res = run_command(args, timeout)
    res["forge"] = parse_forge(res["stdout"])
    return res
