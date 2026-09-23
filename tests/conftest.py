import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return ROOT


@pytest.fixture(scope="session")
def aseprite_path() -> Path:
    from aseprite_runner import AsepriteNotFound, find_aseprite

    try:
        return find_aseprite()
    except AsepriteNotFound:
        pytest.skip("未找到 Aseprite，跳过集成测试")
