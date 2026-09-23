# aseprite-pixel-forge

让任何 AI agent 通过 Aseprite 无头 CLI 程序化创作游戏像素素材（精灵图/道具/建筑/树木等）。

- **skill 入口**：`SKILL.md`（Agent Skills 标准；安装到 `~/.agents/skills/aseprite-pixel-forge`）
- **设计规格**：`docs/superpowers/specs/2026-09-23-aseprite-pixel-forge-design.md`
- **实现计划**：`docs/superpowers/plans/2026-09-23-aseprite-pixel-forge.md`

## 快速开始（开发/手动使用）

```bash
py -3 scripts/forge.py doctor                     # 环境自检
py -3 scripts/forge.py style validate styles/left-hand-of-god.json
py -3 scripts/forge.py gen tree --style styles/left-hand-of-god.json --out forge-build/tree --count 24 --seed 1000
py -3 scripts/forge.py check forge-build/tree --style styles/left-hand-of-god.json
py -3 scripts/forge.py preview forge-build/tree --sheet forge-build/tree-preview.png
py -3 scripts/forge.py install                    # 安装为全局 skill
```

## 测试

```bash
py -3 -m pytest tests/ -q
```
