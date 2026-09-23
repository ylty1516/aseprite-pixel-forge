# aseprite-pixel-forge v1 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。执行者：Pi（内联执行模式，用户已授权全权按推荐执行）。

**目标：** 构建 aseprite-pixel-forge skill v1：任何 agent 可经 Aseprite 无头 CLI 程序化创作自然物像素素材（《神之左手》哥特风验收）。

**架构：** 混合三层（引擎 Python + 技法库/配方 Lua + 方法论 references），生成 N 选优 + 数值质检 + vision 筛选 + 进化迭代闭环。详见 `docs/superpowers/specs/2026-09-23-aseprite-pixel-forge-design.md`。

**技术栈：** Python 3.13（pytest/PIL/numpy）、Aseprite 1.3.18 CLI（`-b --script --script-param`）、Lua（Aseprite 内置）、Agent Skills 标准。

---

## 文件结构（职责锁定）

| 文件 | 职责 |
|------|------|
| `scripts/aseprite_runner.py` | 定位 Aseprite；无头执行 script+params；FORGE 协议解析；超时/错误 |
| `scripts/style.py` | style spec 校验；派生 .gpl 与 `_style.lua`；色板合规判定 |
| `scripts/quality.py` | 数值质检指标；放大预览；联系表；进化参数突变 |
| `scripts/exporters.py` | 单图导出；PIL 图集打包 + JSON |
| `scripts/forge.py` | argparse 统一入口（find-aseprite/style/gen/check/preview/evolve/export/install/doctor） |
| `lua/lib/px.lua` | 技法库：rng/形状 mask/明暗/轮廓/dither/cluster/perturb/speckle/carve/JSON |
| `lua/gen.lua` | 生成入口：describe 与 generate 两模式；pcall + FORGE 输出 |
| `lua/recipes/nature/{tree,bush,rock,flower,tile,ruin}.lua` | 六配方 |
| `styles/left-hand-of-god.json` | 哥特验收 style spec |
| `references/*.md` | 技法/规格/rubric/CLI/工作流文档 |
| `SKILL.md` | agent 入口 |
| `tests/*` | pytest 单测+集成；`tests/lua/*` 金样 |

## 锁定的接口契约

**style JSON（节选）**：
```json
{
  "name": "left-hand-of-god", "canvas": {"tile": 32, "default_size": 32},
  "lighting": {"direction": "top-left"},
  "outline": {"policy": "selective", "color": "#0d0a12"},
  "detail": {"dither": "sparse"},
  "palette": {"ramps": {"stone": ["#2a2635", "...5 阶暗→亮"]}, "utility": {"outline": "#0d0a12"}}
}
```

**gen.lua 协议**（`--script-param` 键）：`mode=describe|generate`、`recipe=<abs.lua>`、`style=<abs._style.lua>`、`lib=<abs px.lua>`、`seed=int`、`name=str`、`out=dir`、`size=WxH`、`params=k=v;k=v`。
输出行：`FORGE:{"ok":true,"files":{"aseprite":"...","png":"..."},"describe":{...},"error":null}`

**recipe 契约**：返回表 `{name, category, size={w,h}, params={key={type,min,max,values,default}}, generate=function(ctx)}`，ctx=`{style, params, rng, seed, size, px}`。

**manifest.json**：`{recipe, style, round, candidates:[{id,seed,params,files,metrics,selected,score}]}`。

---

### 任务 1：骨架与工具链

**文件：** 创建 `.gitignore`、`README.md`、`tests/conftest.py`

- [ ] 步骤 1：`.gitignore`（`__pycache__/`、`*.pyc`、`.pytest_cache/`、`forge-build/`、`*.tmp`）
- [ ] 步骤 2：`README.md`（项目说明、快速开始、指向 SKILL.md）
- [ ] 步骤 3：`tests/conftest.py`（把 `scripts/` 加入 sys.path；`HAS_ASEPRITE` fixture）
- [ ] 步骤 4：`py -3 -m pytest tests/ -q` 预期 collected 0，exit 5（无测试）→ 可接受
- [ ] 步骤 5：Commit

### 任务 2：aseprite_runner.py（TDD）

**文件：** 创建 `scripts/aseprite_runner.py`、`tests/test_runner.py`

- [ ] 步骤 1：测试先写（关键行为）：
```python
def test_build_args_uses_list_no_shell(tmp_path):
    args = build_args(Path("aseprite.exe"), Path("gen.lua"),
                      {"seed": 1001, "name": "t1"}, timeout=120)
    assert args[0] == "aseprite.exe" and "-b" in args
    assert "--script" in args and "gen.lua" in args[args.index("--script") + 1]
def test_find_aseprite_env_override(monkeypatch, tmp_path): ...
def test_parse_forge_line():
    out = 'noise\nFORGE:{"ok": true, "files": {}}\n'
    assert parse_forge(out) == {"ok": True, "files": {}}
def test_run_script_timeout(reason):  # 用假 exe（python -c sleep）模拟
```
- [ ] 步骤 2：运行 `py -3 -m pytest tests/test_runner.py -q` 确认失败
- [ ] 步骤 3：实现：`find_aseprite()`（env `ASEPRITE_PATH` → `~/.aseprite-pixel-forge/config.json` → 常见路径清单（Windows: `F:/SteamLibrary/.../Aseprite/Aseprite.exe`、`C:/Program Files/Aseprite/Aseprite.exe`、Steam 默认库；macOS/Linux 常见）→ `shutil.which`）；`build_args()`；`run_script()`（`subprocess.run(shell=False, timeout=...)`，返回 `{ok, forge, stdout, stderr, code}`）；`parse_forge()`。
- [ ] 步骤 4：测试通过
- [ ] 步骤 5：Commit（`feat(runner): Aseprite 无头执行封装`）

### 任务 3：style.py + 哥特色板（TDD）

**文件：** 创建 `scripts/style.py`、`styles/left-hand-of-god.json`、`tests/test_style.py`

- [ ] 步骤 1：测试：load 校验缺失字段报错；`export_gpl` 行数与色值；`write_style_lua` 含 `ramps` 与 `lighting`；`check_png_compliance` 对合成 PNG（PIL 画合规/违规各一张）判定正确
- [ ] 步骤 2：确认失败
- [ ] 步骤 3：实现 style.py（`load_style/validate/export_gpl/write_style_lua/check_png_compliance`，合规比对用 numpy RGBA 展平 + set 比较）
- [ ] 步骤 4：编写 `styles/left-hand-of-god.json`：12 ramp × 5 阶（shadow/stone/stone_warm/soil/bark/wood_dead/moss/foliage_dark/foliage_dead/bone/iron/ember/frost 中取 12，值在实现时按色相偏移规则精修）；`utility.outline=#0d0a12`
- [ ] 步骤 5：`py -3 -m pytest tests/test_style.py -q` 通过；`py -3 scripts/forge.py style validate styles/left-hand-of-god.json`（此步 later，T5 后回验）
- [ ] 步骤 6：Commit

### 任务 4：px.lua 技法库 + Lua 金样测试

**文件：** 创建 `lua/lib/px.lua`、`tests/lua/test_px.lua`、`tests/lua/run_px_tests.py`

- [ ] 步骤 1：写 Lua 断言（在 Aseprite 内跑）：mask disk 面积/边界；paintShaded 光照方向取向（左上亮、右下暗）；outline 仅外缘且选择性策略下影侧更全；dither 只改过渡带；rng 同 seed 序列一致；perturb 不改空区
- [ ] 步骤 2：`run_px_tests.py` 经 runner 执行，断言 FORGE ok 与各 `ASSERT` 行
- [ ] 步骤 3：实现 px.lua（函数契约见"锁定接口"节；paintShaded 采用 mask 边距光照模型 + 2×2 块级 jitter；clusterize 做 2×2/三角形簇合并；carve 画 1px 走向线）
- [ ] 步骤 4：测试通过
- [ ] 步骤 5：Commit

### 任务 5：gen.lua + forge.py CLI（TDD + 集成）

**文件：** 创建 `lua/gen.lua`、`scripts/quality.py`、`scripts/exporters.py`、`scripts/forge.py`、`tests/test_quality.py`、`tests/test_integration.py`

- [ ] 步骤 1：单测 quality/exporters：指标（合规/尺寸/空图/触边/色数）；联系表尺寸与标签存在；进化突变确定性（同 seed 同结果）；图集 JSON 帧坐标正确
- [ ] 步骤 2：确认失败后实现 quality.py、exporters.py（PIL `load_default(size=)` 标签；联系表含 6x 与 1x 双视图）
- [ ] 步骤 3：实现 gen.lua（describe/generate；pcall 包裹；手写最小 JSON 编码）
- [ ] 步骤 4：实现 forge.py 子命令全部；`gen` 流程 = describe → 每候选确定性采样参数（`random.Random(seed+i)`）→ runner → manifest
- [ ] 步骤 5：集成测试（有 Aseprite 才跑）：用临时小配方生成 1 图 → png 存在 + 色板合规 + 同 seed 两次 sha256 相同；4 候选批次 manifest 完整
- [ ] 步骤 6：全测试通过；Commit

### 任务 6：六配方 + 质量迭代（核心验收）

**文件：** 创建 `lua/recipes/nature/{tree,bush,rock,flower,tile,ruin}.lua`

- [ ] 步骤 1：`tree.lua`（kind: broadleaf/dead/conifer；树干细分+枝条+树冠 blob 簇+苔藓）
- [ ] 步骤 2：`bush.lua`、`rock.lua`（S/M/L 角面+裂缝+苔）
- [ ] 步骤 3：`flower.lua`（草簇/墓地百合）、`tile.lua`（草地/泥路/石板/石地，含可拼接边检）、`ruin.lua`（断柱/砖堆/拱残件）
- [ ] 步骤 4：每配方跑 24 候选 → check → preview 联系表 → 本人 vision 评审 → 修配方 → 至少 2 轮进化，收敛出每类 ≥4 变体
- [ ] 步骤 5：导出最终素材包到 `examples/gothic-nature-pack/`（单图 + 图集 + manifest 记录）
- [ ] 步骤 6：`examples/README.md` 诚实质量评估（对照 rubric、差距、路线图）
- [ ] 步骤 7：Commit

### 任务 7：references + SKILL.md + install/doctor

**文件：** 创建 `references/{pixel-art-techniques,style-spec,evaluation-rubric,aseprite-cli,workflow}.md`、`SKILL.md`；补全 `forge.py install|doctor`

- [ ] 步骤 1：references 五文档（技法清单、格式规范、5 维 rubric、CLI 速查、完整工作流含人选/无 vision 降级）
- [ ] 步骤 2：SKILL.md（frontmatter name/description 中英双语；工作流；命令速查；预算默认值）
- [ ] 步骤 3：`forge.py install`（默认 junction，失败退复制；target 默认 `~/.agents/skills/aseprite-pixel-forge`）；`doctor`（aseprite 版本、依赖、style 校验、16×16 冒烟）
- [ ] 步骤 4：`py -3 scripts/forge.py doctor` 通过；安装到 `~/.agents/skills/`
- [ ] 步骤 5：Commit

### 任务 8：独立审查与收尾

- [ ] 步骤 1：fresh-context reviewer 子代理审查（对照规格检查接口/错误处理/测试完整性）
- [ ] 步骤 2：修复审查发现；全测试重跑
- [ ] 步骤 3：verification-before-completion：跑 doctor + 集成测试 + 完整演示命令并记录输出
- [ ] 步骤 4：最终 Commit；更新设计文档状态；向用户汇报（含诚实质量评估）

---

## 自检记录

- 规格覆盖：§4 引擎→T2/T3/T5；§4.3 技法库→T4；§4.4 闭环→T5/T6；§5 配方→T6；§6 错误处理→T2/T5（export 拒绝、批次容错）；§7 测试→T2-T5；§8 部署→T7；§1 验收→T6
- 占位符扫描：无 TODO；每任务含文件/命令/预期
- 类型一致性：`FORGE:` 协议、manifest、recipe ctx 在 T4/T5/T6 间命名一致（`px.paintShaded(img, mask, ramp, opts)` 等）
