# Aseprite CLI 与脚本速查（本工具链相关）

## 无头执行

```bash
aseprite -b [--script-param k=v ...] --script path/to/script.lua
```

**⚠ 关键坑（Aseprite 1.3.x 实测）：** `--script-param` 必须放在 `--script` **之前**，
否则参数不会进入 `app.params`（静默忽略）。本项目的 runner 已自动保证顺序。

脚本内读取：`app.params["key"]`（全部为字符串）。
脚本向调用方回传：`print('FORGE:{...}')` 单行 JSON（标准输出）。

## 常用导出参数（本工具链里由 Lua 直接存盘，以下供手工使用）

| 参数 | 用途 |
|------|------|
| `--save-as out.png` | 导出（格式随扩展名） |
| `--scale N` | 放大导出（预览用） |
| `--palette p.gpl` | 应用色板 |
| `--sheet out.png --data out.json --format json-hash` | 图集+元数据 |
| `--sheet-type packed/rows/columns` | 图集布局 |
| `--trim` / `--extrude` / `--shape-padding` | 图集细节 |
| `--split-tags` / `--frame-range` | 按 tag/帧段导出 |
| `--color-mode indexed --dithering-algorithm ordered` | 量化 |

## Lua API 常用点（Aseprite 1.3，Lua 5.4）

```lua
local img = Image(w, h, ColorMode.RGB)
img:clear(app.pixelColor.rgba(0,0,0,0))
img:putPixel(x, y, app.pixelColor.rgba(r,g,b,255))
img:getPixel(x, y)
img:saveAs("out.png")

local sprite = Sprite(w, h, ColorMode.RGB)
sprite:newCel(sprite.layers[1], 1, img, Point(0, 0))
sprite:saveCopyAs("out.aseprite")
```

- `app.params`：CLI 透传参数（字符串）。
- 位运算（`~ << >> &`）可用 → 用于确定性 PRNG（本库 `px.rng`）。
- `dofile(absolute_path)` 载入本库模块；本仓库全部用 `dofile` + 绝对路径，避免 `require` 搜索路径问题。
- 脚本顶层错误会让进程非零退出/崩溃：本仓库 `gen.lua` 全程 `pcall`，错误以 `FORGE:{"ok":false,...}` 返回。
