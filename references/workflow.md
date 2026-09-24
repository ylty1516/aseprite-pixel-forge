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

## 6. 帧动画（植物类配方）

- 用 `frames` 参数（1–6）输出多帧；`fps` 保留参数控制 .aseprite 帧时长（默认 8）；
- **关键帧写法（必须）**：同一 seed 逐帧重建基础形态（rng 不动），仅用 `ctx.phase` 叠加帧间差异——
  循环无缝、确定性不破坏（参看 `tree.lua` 树冠摆动 / `bush.lua` 团簇呼吸 / `flower.lua` 的 `px.shear` 弯曲）；
- 动画纪律：根部固定、幅度 1–3px、帧数 4–6、相邻帧剪影必须真实变化（不是整体平移）；
- 导出动图：`forge export <build> --out <dir> --pick ... --gif`（经 Aseprite 保存循环 GIF）；
- 把已选定的静态候选转成动画版：从 `pack.json` 提取 `{seed, params}` 写入 params.json，
  然后 `forge gen <recipe> --params-file params.json --param frames=4`。

## 7. 场景渲染（大气光影/叙事构图）

```bash
python scripts/forge.py scene scenes/bloodmoon-ruins.lua --out <目录> --frames 8 --gif
python scripts/forge.py scene scenes/<场景>.lua --out <目录> --time <时段> --frames 1
python scripts/forge.py scene scenes/<场景>.lua --out <目录> --size 320x135   # 小尺寸快渲
```

- 场景谱是 Lua 表（`scenes/*.lua`）：`size/seed/frames/fps/time/layers/times/grades`；
- **图层类型**（按顺序绘制）：

| 类型 | 作用 | 关键参数 |
|------|------|----------|
| `sky` | 抖动渐变天幕 | ramp/from/to |
| `stars` | 星空（相位闪烁） | count/ymax |
| `moon` | 月盘 + 抖动光晕 | x/y/r/glow/corrupt（血月） |
| `ridge` / `treeline` | 远山 / 树线剪影（视差纵深） | y/amplitude/height/level |
| `hills` | 平滑起伏丘陵（正弦叠加，适合草原/苔原） | y/amplitude/level |
| `megastructure` | 钢铁巨构天际线（塔楼/骨架/天线/塔吊） | y/hmin~hmax/wmin~wmax/gapmin~gapmax/frame_prob/antenna_prob/crane_prob |
| `clouds` | 软边抖动云带 | count/y0/y1/density/wmin~wmax |
| `ground` | tile 平铺（可多 variant） | tiles={...}/y |
| `sprite` | 放入素材（底部中心锚；有 `{name}_f2..` 时自动按相位播放多帧） | folder/name/x/y |
| `grade` | 时段调色（ramp→ramp 抖动交叉） | preset |
| `light` | 火把光池（芯+晕双源、地面椭圆）+ 火焰 + 暖色池 | x/y/r/core_r/strength/squash/warm_r/flame |
| `fog` | 大气雾（深度梯度） | ramp/y0/strength |
| `rays` | 光束（可 ember 色光柱） | x/y/angle/spread/count/strength |
| `embers` | 余烬/萤火粒子 | count/范围 |
| `fg_band` | 前景剪影框景 | y/amplitude/density |

- **时段系统**：`times = { day = { sky_ramp=, sky_from=, sky_to=, hide={...}, moon_corrupt=, grade=, fog_strength= }, ... }`；
- **调色预设**：`grades = { bloodmoon = { ["foliage_dark"] = { target="shadow", blend=0.8 }, ... } }`
  （blend 为抖动量，0–1；色板安全，无混色）；
- **光源写法要点**：`light` 用“内核+光晕”双源（`core_r` 小半径高亮 + `r` 宽半径柔光），
  `squash>1` 把光池压成地面透视椭圆；暖色由 `warmPool` 单独完成（中心近实心、边缘抖动），
  不要把整片区域均匀抖向暖色（会产生“闪粉”噪感）。粒子（`embers`）宁少勿多：集中在地面光源附近（每处 3–6 颗）。
- 所有效果须保持色板合规（forge scene 自动逐帧检查，违规即报错）。

## 8. 沉淀新配方（让库长大）

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
