---
name: aseprite-pixel-forge
description: "Aseprite 程序化像素美术工坊：让 agent 通过 Aseprite 无头 CLI（Lua 脚本）批量创作游戏像素素材（树木/岩石/花草/地形/遗迹/人物与建筑扩展），内建风格规格、像素技法库、数值质检、生成-选优-进化闭环与图集导出。Use when creating or generating game pixel art, sprites, tiles, props, or building an art pipeline around Aseprite. 当用户要生成游戏素材、像素图、精灵图、tile、道具、场景物件，或要求调用 Aseprite 画图时使用。"
license: MIT
---

# aseprite-pixel-forge

程序化像素美术工坊。核心思想：**质量不来自单个生成器，而来自"风格规格 + 技法库 + 生成 N 选优 + 进化"的机制**。
支持任何有 Aseprite 的机器与任何遵循 Agent Skills 标准的 agent（pi / Claude Code / Codex 等）。

## 快速开始

> 命令均在 **skill 根目录** 执行；`--out` 指向你自己的工作区（如 `~/forge-build/...`），
> 不要写进 skill 安装目录（`~/.agents/skills/...` 可能是只读共享位置）。

```bash
# 0) 环境（一次）
python scripts/forge.py doctor

# 1) 生成一轮候选（以树木为例）
python scripts/forge.py gen tree --style styles/left-hand-of-god.json --out build/tree --count 24 --seed 1000

# 2) 质检 + 预览（联系表：放大+1x 并排，带编号）
python scripts/forge.py check build/tree
python scripts/forge.py preview build/tree --scale 6 --cols 6

# 3) 看联系表选优 → 进化一轮
python scripts/forge.py evolve build/tree --keep 1,5,9 --out build/tree-r2

# 4) 导出成品（裁剪透明边 + 图集 + 源文件）
python scripts/forge.py export build/tree-r2 --out out/tree --pick 1,3 --sheet
```

> Windows 上把 `python` 换成 `py -3`。前提：本机安装 Aseprite（1.3+）；找不到时用
> `python scripts/forge.py find-aseprite --set <Aseprite 可执行文件路径>`。

## 工作流（必须遵守）

1. **先有 style spec**：新项目先建 `styles/<项目>.json`（格式见 references/style-spec.md），
   色板是"美术判断"的载体，一切生成服从它；
2. **生成 N 个候选**（≥16），**check 先剪枝**（色板违规/空图直接淘汰）；
3. **preview 出联系表**，用视觉按 rubric 打分选优（references/evaluation-rubric.md）；
   无视觉能力时走 rubric 的降级流程（数值筛选 + 人工挑选）；
4. **evolve 进化** 1–2 轮再筛（参数扰动 + 重掷）；
5. **export 导出**（默认拒绝色板违规产物）。

详细流程、预算与配方开发指南：`references/workflow.md`。

## 内置配方（v1：自然物）

`tree`（阔叶/枯树/松柏）· `bush`（含浆果/微光）· `rock`（S/M/L）· `flower`（草簇/百合/蕨）·
`tile`（草地/泥路/石板路/石地）· `ruin`（断柱/砖堆/拱残件）· `smoke`（调试小球）
——全部可通过 `--param` 固定参数定向生成。

## 扩展新品类（建筑/人物等）

在 `lua/recipes/<category>/` 新建配方：声明 `params` + 实现 `generate(ctx)`，
只用 `ctx.px` 技法库与 style ramps（模板见 `lua/recipes/nature/` 与 references/workflow.md §6）。
人物建议路线：部件系统（头/身/衣分层）+ 参数化拼装；动画用帧序列参数化生成。

## 关键文件

| 路径 | 作用 |
|------|------|
| `scripts/forge.py` | 统一 CLI（gen/check/preview/evolve/export/doctor/install） |
| `lua/lib/px.lua` | 技法库：形状/明暗/轮廓/抖动/簇/扰动/点缀（全部确定性） |
| `lua/gen.lua` | 生成入口（describe/generate 协议） |
| `styles/` | 风格规格（验收基准：left-hand-of-god） |
| `references/` | 技法规则 / style 格式 / rubric / CLI 手册 / 工作流 |
| `examples/gothic-nature-pack/` | v1 验收产出（6 品类 48 精灵，含质量报告） |

## 行为准则

- **不手改** `_derived/` 与 manifest 中的 seed；要变风格改 style JSON，要变形态改参数/配方；
- 每次导出保留 `source_aseprite/`（人工精修入口 = L3 出口条款）；
- 声称"完成"前必须：`forge check --strict` 通过 + 联系表视觉确认 + doctor 通过；
- 产出目录写 `pack.json`（可复现记录），不覆盖已有记录。
