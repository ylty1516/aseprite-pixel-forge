# aseprite-pixel-forge 设计规格

> 2026-09-23 · 状态：已批准（用户授权按推荐方案执行）

## 1. 背景与目标

让**任何 AI agent** 能通过 Aseprite 程序化创作游戏原画精灵图（人物、背景、建筑、树木等）。
路线：**程序化绘制**（agent 写/调 Lua 代码，经 Aseprite 无头 CLI 直接画像素），不依赖图像生成模型。

**终极目标（L3 野心）**：全品类商业成品级；
**出口条款**：接受"人物/复杂风格后续可能需人工精修或图像模型补强"，引擎预留该接口（不影响 v1 范围）。

### 成功标准（v1）
在《神之左手》哥特暗黑风格下，全流程无人工干预产出自然物素材包：
- ≥6 品类 × 每类 ≥8 候选、留存 ≥4 变体（树/灌木/岩石/花草/地形 tile/遗迹残件）
- 色板 100% 合规；1x（480×270 下）可读性过 rubric；确定性可复现（同 seed 同图）
- 全程 agent 驱动：需求 → 风格规格 → 生成 → 数值质检 → vision 筛选 → 进化 → 导出
- 附诚实质量评估（与目标差距、下一步路线）

## 2. 可达区间（诚实评估）

| 品类 | 纯程序化现实上限 |
|------|----------------|
| 树/灌木/岩石/花草/地形 tile/遗迹 | 低复杂度风格下接近成品级，v1 主战场 |
| 简单建筑（体块+屋顶+门窗+配色） | 风格统一的可用素材 |
| 人物/怪物 | 高质量底稿（轮廓/配色/站姿），逐帧动画为硬骨头 |
| 背景（视差场景） | 可由 tile/道具组合，场景级艺术方向仍弱 |

质量不来自"某个生成器写得好"，而来自**机制**：生成 N 选优 + 技法约束 + 自评迭代闭环。

## 3. 架构：混合三层

```
分层        载体                          职责
─────────────────────────────────────────────────────────────
引擎层      scripts/ (Python) + lua/lib    CLI 封装、风格规格、技法库、质量闭环、导出
配方层      lua/recipes/                   品类参数化生成器（v1: 自然物 ×6）
方法论层    SKILL.md + references/         工作流、像素画技法、评估 rubric、验收基准
```

### 3.1 仓库即 skill

仓库根 = skill 根（`SKILL.md` 位于根目录，符合 Agent Skills 标准）。
开发于本地工作区（任意路径均可）；
安装 = 同步到 `~/.agents/skills/aseprite-pixel-forge`（pi 与所有遵循标准的 agent 通用发现位置）。

### 3.2 目录结构

```
aseprite-pixel-forge/
├── SKILL.md                     # 入口
├── references/                  # 按需加载
│   ├── pixel-art-techniques.md
│   ├── style-spec.md
│   ├── evaluation-rubric.md
│   ├── aseprite-cli.md
│   └── workflow.md
├── scripts/
│   ├── forge.py                 # 统一 CLI 入口
│   ├── aseprite_runner.py       # 定位 + 无头执行 + 错误捕获
│   ├── style.py                 # style spec 校验/派生（.gpl / _style.lua）
│   ├── quality.py               # 数值质检 + 预览 + 联系表 + 进化
│   └── exporters.py             # PNG/图集/清单导出
├── lua/
│   ├── lib/px.lua               # 技法库（+ 子模块）
│   ├── gen.lua                  # 生成入口（--script-param 协议）
│   └── recipes/nature/*.lua     # tree/bush/rock/flower/tile/ruin
├── styles/left-hand-of-god.json # 验收基准 style spec
├── tests/                       # pytest + Lua 金样测试
└── examples/                    # 产出示例与质量说明
```

## 4. 引擎层设计

### 4.1 aseprite_runner.py
- 定位顺序：环境变量 `ASEPRITE_PATH` → 用户配置 `~/.aseprite-pixel-forge/config.json` → 常见路径（Win/macOS/Linux，含 Steam 库）→ PATH
- 执行协议：`aseprite -b --script gen.lua --script-param k=v ...`（**shell=False 列表参数**，避免引号/中文路径问题）
- 超时默认 120s/次；stdout 中 `FORGE:{...}` 行作为结构化结果（含产出文件、seed、错误）
- 批次生成：单个失败不中断整批，manifest 记录失败项

### 4.2 style spec（JSON）

字段：`name/display/canvas{tile,default_size}/palette{ramps{key:[暗→亮 hex]}, utility}` /
`lighting{direction}` / `outline{policy, color_source}` / `detail{dither}` / `notes`。
- `style.py validate` 校验；`gpl` 生成 Aseprite 色板；`lua` 生成 `_style.lua` 供配方 `dofile`
- 合规判定：PNG 中所有不透明像素必须 ∈ 色板（**严格模式**，不做自动量化——保确定性）
- 《神之左手》色板：石/苔/枯木/暗叶/骨/铁/余烬暖色点缀/土壤/阴影 等 ~10 条 ramp × 5 阶（带色相偏移）

### 4.3 技法库 lua/lib/px.lua（质量的核心载体）

mask 驱动：配方先构造形状掩码（2D 表），库统一做**明暗/轮廓/纹理/扰动**——一致性由此保证。
- 形状：`disk/ellipse/rect/blob(径向噪声)/line/polygon`
- 明暗：`paintShaded`（光照方向 + 边距调制 + 抖动 → ramp 索引映射）
- 轮廓：`outline`（selective 策略：影侧重、光侧轻/断线）
- 纹理：`dither`（Bayer/棋盘过渡）、`clusterize`（簇状明暗，反几何感）、`perturb`（边界扰动）、`speckle`（苔藓/杂物点缀）、`carve`（树皮/裂纹线）
- 所有随机走内置种子 PRNG（xorshift），**杜绝 os.time/全局随机**，保确定性

### 4.4 质量闭环（数据流）

```
1. forge gen <recipe> --style S --out D --count 24 --seed 1000
   → 每候选: .aseprite + .png + manifest.json(seed/params/指标)
2. forge check D --style S
   → 数值质检: 色板合规/尺寸/空图/触边/色数/亮度分布 → 淘汰不合规
3. forge preview D --sheet --scale 6
   → 放大预览 + 编号联系表 PNG（agent 用 vision 审阅）
4. agent 按 references/evaluation-rubric.md 打分（可读性/剪影/色板纪律/明暗逻辑/簇干净度 0-5）
5. forge evolve D --keep 1,5,9 --out D2 [--rounds 2]
   → 保留种子参数±扰动 + 重掷随机 → 新一轮 gen
6. 收敛后: forge export D --pick ... --format png|sheet
```

预算默认：N=24，K=4，进化 ≤2 轮（可配）。数值质检先剪枝（廉价），vision 只审短名单。

### 4.5 导出
- `png`：单图（原名/tag 化）；`sheet`：PIL 拼图 + JSON 图集（frames: name→{x,y,w,h}，Godot 可直读）
- 保留 `.aseprite` 源文件（人可继续精修 = 出口条款接口）
- 不做引擎专用 .import 生成（版本相关），在 references 里写 Godot 导入设置说明

## 5. 配方层 v1（自然物 ×6）

统一结构：`params`（带类型/范围/默认） + `generate(ctx)`（ctx: style/params/rng/size）。
`lua/gen.lua` 为唯一入口：解析 `app.params` → dofile 配方 → 产出 .aseprite/.png → 打印 `FORGE:{...}`。

| 配方 | 内容 | 主要变体维度 |
|------|------|------------|
| tree | 阔叶/枯树/松柏；树干+枝结构+树冠簇 | 高度/树冠占比/不对称/苔藓 |
| bush | 灌木簇+叶簇+发光小花可选 | 大小/密度/花色 |
| rock | 角面岩石，S/M/L | 尺寸/棱角/裂缝/苔藓 |
| flower | 草丛/墓地百合/枯枝草簇 | 密度/花色/高度 |
| tile | 草地/泥路/石板/石地 32×32 | 纹理密度/磨损/裂纹 |
| ruin | 断柱/砖堆/拱残件 | 体量/破损度/苔藓 |

配方可生长：agent 手写成功的代码沉淀回 `recipes/`（方法论写入 workflow.md）。

## 6. 错误处理

| 场景 | 处理 |
|------|------|
| Aseprite 未找到 | 明确指引 + `forge find-aseprite --set <path>`，写入用户配置 |
| Lua 运行错误 | 非零退出 + stderr 捕获；gen.lua 内 pcall 先打印 `FORGE:{"ok":false,...}` |
| 超时 | kill + 报告候选 id；调大 `--timeout` |
| 批次部分失败 | manifest 标记 failed 继续；最终报告失败清单 |
| 色板违规 | check 报告违规色；export 默认拒绝，`--force` 可越权 |
| 无 vision 能力的 agent | rubric 中说明降级流程：仅数值指标 + 用户人工挑选 |

## 7. 测试策略

- **单元（pytest）**：style 校验/派生、质量指标（合成 PNG）、进化突变、runner 参数构造与错误路径
- **集成**：真跑 Aseprite——单候选生成 → PNG 存在 + 色板合规 + 同 seed 两次 sha256 相同；mini 批次 4 候选
- **Lua 金样**：tests/lua/ 小尺寸固定输入 → 断言 outline/paint 像素结果
- **验收**：6 品类全流程 + 联系表人工/vision 评审记录（examples/README.md）
- 依赖缺失（Aseprite 不存在时）集成测试 skip 并给出说明

## 8. 部署与跨 agent

- `forge.py install`：默认复制/junction 到 `~/.agents/skills/aseprite-pixel-forge`；`--target` 可换
- pi 原生读取 `~/.agents/skills/`；Claude Code/Codex 等经各自 settings 指向同目录
- `forge.py doctor`：aseprite 定位、Python 依赖、style 校验、端到端冒烟（生成 1 张 16×16 测试图）

## 9. 路线图

- v1（本规格）：自然物 ×6 + 引擎 + 《神之左手》验收
- v2：建筑 → 背景组件（视差层素材、场景拼装）→ 人物（部件系统 + 多方向）
- v3：动画（帧序列生成、简单摆动/行走）、图像模型补强接口（初稿→像素化管线）、更多 style spec

## 10. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 程序化"几何感"重 | 技法库强扰动/簇状明暗 + 生成选优进化（机制兜底） |
| 配方质量参差 | rubric 硬门槛 + 进化轮 + 人工抽检记录 |
| Aseprite 版本差异 | 只依赖 1.3.x 稳定 CLI 特性；doctor 冒烟检测并报版本 |
| 大规模候选 token 消耗 | 数值剪枝先行、联系表批阅、预算可配 |

## 11. 实现偏差记录（v1 落地修正，2026-09-23）

以下差异已在实现中采纳并同步到 SKILL.md / references，作为正式口径：

1. **命令口径**：`evolve` 无 `--rounds`（单轮进化，多轮=多次调用）；`export` 用 `--sheet` 布尔开关（另有 `--sheet-cols` / `--prefix`）；`preview` 用 `--out`。
2. **outline 字段**：`outline.color` 为必填（替代本草案中的 `color_source`）。
3. **技法库命名**：无独立 `ellipse`（由 `disk(m,cx,cy,rx,ry)` 覆盖）；`clusterize` 实现为 `clusterJitter`（2×2 块级）。
4. **runner**：`--script-param` 必须置于 `--script` **之前**（Aseprite 1.3.18 实测硬要求）；查找顺序为 env → config → PATH → 常见路径。
5. **色板规模**：基准 style 为 13 ramp × 5 阶 = 65 色（±outline）。
6. **已知缺口（记入 v1.1 候选，不在 v1 承诺内）**：tile 拼接边检；manifest `score` 为占位字段（`selected` 由 evolve/export 回写）；人物/建筑品类按路线图 v2。

## 12. v1.5 动画升级（2026-09-23）

“原生动画缺失”已在 v1.5 补齐（树/灌木/花草）：

1. **gen 协议扩展**：`frames`（1–6，非采样参数）+ 保留参数 `fps`；同 seed 逐帧重建基础形态，`ctx.phase` 叠加帧间差异，循环无缝且确定性保持；
2. **技法库**：新增 `px.shear`（行级弯曲，根部固定/宽度保持/连通保持）；配方接入：tree=树冠相位摆动、bush=团簇呼吸、flower=叶片弯曲；
3. **导出**：`forge export --gif` 经 Aseprite 将多帧 `.aseprite` 直接导出循环 GIF；
4. **复现机制**：`gen --params-file <{seed,params}>` 可将已选定静态候选精确重生成动画版（pack.json 即参数源）。
