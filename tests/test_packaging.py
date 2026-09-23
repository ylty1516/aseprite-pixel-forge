"""打包与产出声明的回归防护（不需要 Aseprite）。"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from style import check_png_compliance, load_style  # noqa: E402


def test_skill_frontmatter_valid():
    text = (ROOT / "SKILL.md").read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    assert m, "SKILL.md 缺少 YAML frontmatter"
    fm = m.group(1)
    name_m = re.search(r"^name:\s*(\S+)\s*$", fm, re.M)
    assert name_m, "缺少 name"
    name = name_m.group(1)
    assert re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name), f"非法 skill 名: {name}"
    assert len(name) <= 64
    desc_m = re.search(r"^description:\s*(.+)$", fm, re.M)
    assert desc_m, "缺少 description"
    assert len(desc_m.group(1)) <= 1024


def test_examples_pack_all_palette_compliant():
    style = load_style(ROOT / "styles" / "left-hand-of-god.json")
    pngs = [p for p in (ROOT / "examples" / "gothic-nature-pack").rglob("*.png")
            if "_sheet" not in p.name]
    assert len(pngs) >= 40, f"示例包精灵数量异常: {len(pngs)}"
    for png in pngs:
        report = check_png_compliance(png, style)
        assert report["ok"], f"{png.name} 色板违规: {report['bad_colors']}"


def test_examples_pack_counts_per_category():
    pack = ROOT / "examples" / "gothic-nature-pack"
    expected = {"trees": 10, "bushes": 8, "rocks": 8, "flowers": 8, "tiles": 9, "ruins": 9}
    for folder, count in expected.items():
        pngs = [p for p in (pack / folder).glob("*.png") if "_sheet" not in p.name]
        assert len(pngs) == count, f"{folder}: 期望 {count} 张，实际 {len(pngs)}"
