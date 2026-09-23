# style spec 格式规范

一份 JSON 描述一个游戏/项目的像素美术规格。所有生成器与质检都以它为准。

## 最小示例

```json
{
  "name": "my-game",
  "display": "我的游戏——暗黑幻想",
  "canvas": {"tile": 32, "default_size": 32},
  "lighting": {"direction": "top-left"},
  "outline": {"policy": "selective", "color": "#0d0a12"},
  "detail": {"dither": "sparse"},
  "palette": {
    "ramps": {
      "stone": ["#262233", "#3b3549", "#575064", "#767089", "#9993ac"],
      "moss":  ["#141c12", "#25331d", "#3a4d2b", "#52683a", "#6d844d"]
    },
    "utility": {"outline": "#0d0a12"}
  },
  "notes": "任意备注"
}
```

## 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | ✅ | 小写连字符；决定派生文件名 |
| `canvas.tile` | | 游戏 tile 尺寸（tile 类配方会参考） |
| `canvas.default_size` | ✅ | 无 recipe.size 时的默认画布边长 |
| `lighting.direction` | ✅ | `top-left` / `top` / `top-right` / `left` / `right` / `bottom-left` / `bottom` / `bottom-right` |
| `outline.policy` | ✅ | `selective`（影侧实、光侧断）/ `full` / `none` |
| `outline.color` | | 轮廓色（通常 = shadow 最深阶） |
| `detail.dither` | | `none` / `sparse` / `medium`（提示生成器抖动密度） |
| `palette.ramps` | ✅ | 键=材质名，值=**暗→亮** 5 阶 hex 数组（最少 2 阶） |
| `palette.utility` | | 额外单色（outline 等） |

## 色阶（ramp）设计方法

1. 每个材质一条 ramp：中间调为基准色，向暗端加蓝紫、向亮端加暖（或按材质气质）。
2. 5 阶起步；跨度宜暗（暗部占 2/3），确保 gothic/夜景风格。
3. 示例材质集：shadow / stone / stone_warm / soil / bark / wood_dead / moss / foliage_dark / foliage_dead / bone / iron / ember（暖点缀）/ frost（冷高光）。
4. 单项目总色数建议 ≤64（本库基准 style 65 色）。

## 命令

```bash
python scripts/forge.py style validate styles/xxx.json   # 校验
python scripts/forge.py style gpl  styles/xxx.json out.gpl   # 导出 Aseprite 色板
python scripts/forge.py style lua  styles/xxx.json out.lua   # 派生 Lua 模块（gen 内部自动做）
```

新建项目 = 新建一份 style JSON；其余流程完全复用。
