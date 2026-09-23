# 标准工作流（生成 → 质检 → 选优 → 进化 → 导出）

所有命令以 skill 根目录为工作目录；`python` 可按平台改为 `py -3` 等。

## 0. 一次性准备

```bash
python scripts/forge.py doctor                         # 环境自检（Aseprite/依赖/style/冒烟）
python scripts/forge.py find-aseprite --set <路径>      # 自动找不到时手动指定
python scripts/forge.py style validate styles/left-hand-of-god.json
```

## 1. 生成候选（N 原则：先多后精）

```bash
python scripts/forge.py gen <recipe> --style <style.json> --out <build目录> \
    --count 24 --seed 1000 --param "kind=dead;height=36"   # 多个固定参数用引号包裹
```

- `--count 24`：单轮建议 16–32（质量机制靠"多生成 + 选优"）；
- `--seed`：记录在 manifest 中，全批可复现；
- `--param`：固定某个参数（如只出枯树）；不传则按范围随机采样；
- 产出：每候选 `.aseprite`（源）+ `.png`（图），以及 `manifest.json`（seed/参数/指标）。

## 2. 数值质检（先剪枝）

```bash
python scripts/forge.py check <build目录> [--strict]
```

- 报告色板合规 / 尺寸 / 空图 / 触边 / 色数 / 亮度；
- `--strict` 在有违规时非零退出（CI 用）。

## 3. 视觉审阅与选优

```bash
python scripts/forge.py preview <build目录> --scale 6 --cols 6
```

- 产出 `preview.png`：每格"放大图 + 1x 原尺寸"并排 + 编号；终端打印编号→文件映射；
- agent 用视觉能力按 `references/evaluation-rubric.md` 打分，记下保留编号。

## 4. 进化（可选但推荐一轮以上）

```bash
python scripts/forge.py evolve <build目录> --keep 1,5,9 --out <build2> [--jitter 0.25]
```

- 对保留项的**参数**做范围内扰动 + 重掷随机 → 新一轮候选；
- 反复"check → preview → evolve"直到收敛（默认预算 ≤2 轮）。

## 5. 导出成品

```bash
python scripts/forge.py export <build目录> --out <输出目录> --pick 1,5,9 --sheet
```

- 默认拒绝色板违规（`--force` 可越权）；导出自动裁剪透明边；
- 产出：`名称_NN.png` + `名称_sheet.png/json` + `source_aseprite/`（可人工精修）+ `pack.json`（含 seed/参数）；
- 同目录重复导出不同前缀时清单自动存为 `pack_<prefix>.json`。

## 6. 沉淀新配方（让库长大）

成功的手写绘制代码 → 收敛为 `lua/recipes/<category>/<name>.lua`：

```lua
return {
  name = "名字", category = "nature", size = {32, 32},
  params = { 键 = {type = "int|float|bool|choice", ...范围/values/default} },
  generate = function(ctx)  -- ctx: style/params/rng/seed/size/px
    local img = ctx.px.newImage(ctx.size[1], ctx.size[2])
    -- 形状 mask → px.paintShaded → 纹理/点缀 → px.outline
    return {img = img, mask = mask}
  end,
}
```

要点：
- 只用 `ctx.px`（技法库）与 style ramps，保证一致性与可复现；
- 参数一律声明进 `params`（gen/evolve 才能采样与进化）；
- 参考 `lua/recipes/nature/` 六个现成配方。

## 预算参考（默认值）

| 项 | 默认 | 说明 |
|----|------|------|
| 单轮候选 N | 24 | 16–32 可调 |
| 保留 K | 4 | 3–5 |
| 进化轮数 | ≤2 | 收敛优先 |
| 单次生成超时 | 120s | `--timeout` |
| 每候选耗时 | 1–4s | 32×32 级画布实测 |
