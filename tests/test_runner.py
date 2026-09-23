import json
import sys
from pathlib import Path

import pytest

from aseprite_runner import (
    AsepriteNotFound,
    build_args,
    find_aseprite,
    parse_forge,
    run_command,
    run_script,
)


def test_find_aseprite_env_override(monkeypatch, tmp_path):
    fake = tmp_path / "Aseprite.exe"
    fake.write_text("")
    monkeypatch.setenv("ASEPRITE_PATH", str(fake))
    assert find_aseprite() == fake


def test_find_aseprite_config_file(monkeypatch, tmp_path):
    monkeypatch.delenv("ASEPRITE_PATH", raising=False)
    fake = tmp_path / "aseprite"
    fake.write_text("")
    cfg = tmp_path / "config.json"
    cfg.write_text(json.dumps({"aseprite_path": str(fake)}), encoding="utf-8")
    monkeypatch.setenv("ASEPRITE_FORGE_CONFIG", str(cfg))
    assert find_aseprite() == fake


def test_find_aseprite_not_found(monkeypatch, tmp_path):
    monkeypatch.delenv("ASEPRITE_PATH", raising=False)
    monkeypatch.setenv("ASEPRITE_FORGE_CONFIG", str(tmp_path / "nope.json"))
    monkeypatch.setattr("aseprite_runner._candidate_paths", lambda: iter(()))
    monkeypatch.setattr("aseprite_runner.shutil.which", lambda name: None)
    with pytest.raises(AsepriteNotFound):
        find_aseprite()


def test_build_args_order_and_params():
    args = build_args(Path("aseprite.exe"), Path("gen.lua"), {"seed": 1001, "name": "t1"})
    assert args[0] == "aseprite.exe"
    assert "-b" in args
    assert args[args.index("--script") + 1] == "gen.lua"
    assert args.count("--script-param") == 2
    assert "seed=1001" in args and "name=t1" in args


def test_build_args_extra():
    args = build_args(Path("asp"), Path("s.lua"), {}, extra=["--timeout", "5"])
    assert args[-2:] == ["--timeout", "5"]


def test_parse_forge_line():
    out = 'banana\nFORGE:{"ok": true, "files": {}}\nend\n'
    assert parse_forge(out) == {"ok": True, "files": {}}


def test_parse_forge_missing():
    assert parse_forge("nothing here") is None


def test_parse_forge_broken_json():
    assert parse_forge("FORGE:{not json}") is None


def test_run_command_success():
    res = run_command([sys.executable, "-c", "print('FORGE:{\"ok\": true}')"])
    assert res["ok"] is True and res["code"] == 0
    assert parse_forge(res["stdout"]) == {"ok": True}


def test_run_command_nonzero():
    res = run_command([sys.executable, "-c", "raise SystemExit(3)"])
    assert res["ok"] is False and res["code"] == 3


def test_run_command_timeout():
    res = run_command(
        [sys.executable, "-c", "import time; time.sleep(10)"], timeout=1
    )
    assert res["ok"] is False and res["timeout"] is True


def test_run_command_missing_binary():
    res = run_command(["definitely-not-a-real-binary-xyz"])
    assert res["ok"] is False and res["timeout"] is False


def test_run_script_delegates(monkeypatch, tmp_path):
    calls = {}

    def fake_run_command(args, timeout=120):
        calls["args"] = args
        calls["timeout"] = timeout
        return {"ok": True, "code": 0, "stdout": "FORGE:{}", "stderr": "", "timeout": False}

    monkeypatch.setattr("aseprite_runner.run_command", fake_run_command)
    res = run_script(Path("s.lua"), {"seed": 1}, timeout=42,
                     aseprite=tmp_path / "asp.exe")
    assert res["forge"] == {}
    assert calls["timeout"] == 42
    assert calls["args"][0].endswith("asp.exe")
    assert "seed=1" in calls["args"]
