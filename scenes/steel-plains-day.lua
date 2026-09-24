-- 钢铁巨构平原：白日 · 死亡搁浅式钢铁巨构（骨架外露钢结构）+ 多层雾带朦胧感
-- 渲染：forge scene scenes/steel-plains-day.lua --out <目录> --frames 8 --gif
return {
  name = "steel-plains-day",
  size = { 640, 270 },
  seed = 20260924,
  frames = 8,
  fps = 8,
  time = "day",

  layers = {
    -- 天：奶白浅灰（朦胧底）
    { type = "sky", ramp = "frost", from = 4, to = 5 },
    { type = "clouds", count = 4, y0 = 24, y1 = 70, ramp = "bone", density = 0.28,
      wmin = 60, wmax = 150, hmin = 6, hmax = 13 },

    { type = "moon", x = 478, y = 88, r = 16, glow = 58, corrupt = false, ramp = "bone" },
    { type = "rays", x = 478, y = 88, angle = 2.1, spread = 0.6, count = 3,
      length = 200, strength = 0.11, ramp = "bone", level_base = 3, flicker = 0.08 },

    -- ═══ 最远层：全钢语汇 —— 破碎钢桥横贯 + 越框巨型绗架塔 ═══
    { type = "viaduct", x0 = -24, x1 = 664, y = 126, deck_h = 6, base = 200,
      broken = true, broken_count = 3, debris = false,
      ramp = "iron", level = 1, pier_min = 52, pier_max = 96 },
    { type = "megastructure", y = 176, hmin = 96, hmax = 150,
      wmin = 10, wmax = 20, gapmin = 260, gapmax = 460,
      ramp = "iron", level = 1, colossal = true, colossal_prob = 0.6,
      colossal_scale = 1.75, colossal_width_scale = 1.1, styles = { "frame" } },
    -- 远层重度大气透视（钢铁溶入雾）
    { type = "grade", spec = {
      ["iron"] = { target = "frost", blend = 0.65, shift = 2 },
    } },
    { type = "fog", ramp = "frost", strength = 0.52, baseLevel = 4, levelSpan = 1,
      field = function(_, y)
        local d = (y - 132) / 48
        return math.max(0, 1 - d * d)
      end },

    -- 高空钢缆
    { type = "cables", x0 = -20, x1 = 340, y0 = 44, y1 = 52, sag = 28,
      ramp = "iron", level = 2 },
    { type = "cables", x0 = 360, x1 = 670, y0 = 56, y1 = 42, sag = 24,
      ramp = "iron", level = 2 },

    -- ═══ 中景：钢骨架大厅 + 巨型钢拱门 + 绗架塔（全钢结构）═══
    { type = "megastructure", x0 = 34, x1 = 232, y = 206,
      hmin = 30, hmax = 38, wmin = 72, wmax = 92, gapmin = 300, gapmax = 400,
      ramp = "iron", level = 2, styles = { "steelhall" } },
    { type = "megastructure", x0 = 254, x1 = 336, y = 205,
      hmin = 46, hmax = 58, wmin = 52, wmax = 64, gapmin = 300, gapmax = 400,
      ramp = "iron", level = 2, styles = { "steelarch" } },
    { type = "megastructure", x0 = 348, x1 = 392, y = 205,
      hmin = 62, hmax = 88, wmin = 12, wmax = 16, gapmin = 300, gapmax = 400,
      ramp = "iron", level = 2, styles = { "frame" } },
    { type = "megastructure", x0 = 404, x1 = 556, y = 206,
      hmin = 22, hmax = 30, wmin = 70, wmax = 88, gapmin = 300, gapmax = 400,
      ramp = "iron", level = 2, styles = { "steelhall" } },
    { type = "megastructure", x0 = 572, x1 = 660, y = 205,
      hmin = 38, hmax = 50, wmin = 48, wmax = 60, gapmin = 300, gapmax = 400,
      ramp = "iron", level = 2, styles = { "steelarch" } },
    -- 中景雾带（只按入结构下半部/基座，保留骨架可读性）
    { type = "fog", ramp = "frost", strength = 0.2, baseLevel = 4, levelSpan = 1,
      field = function(_, y)
        local d = (y - 186) / 34
        return math.max(0, 1 - d * d)
      end },

    -- 鸟群（尺度参照）
    { type = "birds", flocks = 2, x0 = 60, x1 = 570, y0 = 54, y1 = 126,
      ramp = "shadow", level = 2 },

    -- 中低空钢缆（带吊杆）
    { type = "cables", x0 = 40, x1 = 640, y0 = 122, y1 = 112, sag = 16,
      ramp = "iron", level = 2, hangers = 26, hanger_len = 3 },

    -- ═══ 地面层次：丘陵 → 草地 → 薄雾 → 近景巨构 ═══
    { type = "hills", y = 198, amplitude = 9, ramp = "foliage_dead", level = 4 },
    { type = "hills", y = 208, amplitude = 6, ramp = "foliage_dead", level = 3 },
    { type = "ground", folder = "tiles", tiles = { "grass_01", "grass_02", "tile_02" }, y = 209 },
    { type = "ground", folder = "tiles", tiles = { "tile_01", "tile_05" }, y = 254 },
    -- 近地面薄雾
    { type = "fog", ramp = "frost", strength = 0.16, baseLevel = 4, levelSpan = 1,
      field = function(_, y)
        local d = (y - 214) / 42
        return math.max(0, 1 - d * d)
      end },

    -- ═══ 近景：巨型钢拱门横跨（玩家尺度参照）+ 绗架塔 ═══
    { type = "megastructure", x0 = 26, x1 = 196, y = 250,
      hmin = 56, hmax = 66, wmin = 128, wmax = 152, gapmin = 400, gapmax = 500,
      ramp = "iron", level = 3, styles = { "steelarch" } },
    { type = "megastructure", x0 = 462, x1 = 502, y = 248,
      hmin = 74, hmax = 96, wmin = 10, wmax = 13, gapmin = 400, gapmax = 500,
      ramp = "iron", level = 3, styles = { "mast" } },
    { type = "megastructure", x0 = 530, x1 = 648, y = 246,
      hmin = 16, hmax = 22, wmin = 84, wmax = 104, gapmin = 400, gapmax = 500,
      ramp = "iron", level = 3, styles = { "steelhall" } },

    -- 物件：礫石 + 草簇（动画·风）+ 野花 + 残骸
    { type = "sprite", folder = "rocks", name = "rock_07", x = 224, y = 216 },
    { type = "sprite", folder = "rocks", name = "rock_05", x = 424, y = 215 },
    { type = "sprite", folder = "rocks", name = "rock_08", x = 330, y = 216 },
    { type = "sprite", folder = "rocks", name = "rock_06", x = 258, y = 252 },
    { type = "sprite", folder = "rocks", name = "rock_02", x = 430, y = 251 },
    { type = "sprite", folder = "flowers", name = "wind_01", x = 62, y = 244 },
    { type = "sprite", folder = "flowers", name = "wind_02", x = 150, y = 250 },
    { type = "sprite", folder = "flowers", name = "wind_03", x = 300, y = 242 },
    { type = "sprite", folder = "flowers", name = "wind_01", x = 118, y = 222 },
    { type = "sprite", folder = "flowers", name = "wind_03", x = 480, y = 224 },
    { type = "sprite", folder = "flowers", name = "wind_01", x = 356, y = 268 },
    { type = "sprite", folder = "flowers", name = "wind_02", x = 520, y = 248 },
    { type = "sprite", folder = "flowers", name = "flower_05", x = 232, y = 246 },
    { type = "sprite", folder = "flowers", name = "flower_02", x = 380, y = 245 },
    { type = "sprite", folder = "ruins", name = "ruin_02", x = 210, y = 262 },

    -- 日间调色：草→枯橄榄提亮，钢件轻微褪入大气
    { type = "grade", preset = "day_sage" },

    -- 浮尘（极少，风感）
    { type = "embers", count = 4, x0 = 40, x1 = 620, y0 = 150, y1 = 250,
      rise = 26, ramp = "bone" },
  },

  times = { day = {} },

  grades = {
    day_sage = {
      ["foliage_dark"] = { target = "foliage_dead", blend = 0.9, shift = 1 },
      ["moss"] = { target = "foliage_dead", blend = 0.65, shift = 1 },
      ["foliage_dead"] = { target = "foliage_dead", blend = 1.0, shift = 1 },
      ["shadow"] = { target = "stone", blend = 0.5 },
      ["stone"] = { target = "frost", blend = 0.2, shift = 1 },
      ["stone_warm"] = { target = "bone", blend = 0.28, shift = 1 },
      ["soil"] = { target = "stone_warm", blend = 0.5, shift = 1 },
      ["bark"] = { target = "stone_warm", blend = 0.35, shift = 1 },
      ["wood_dead"] = { target = "stone_warm", blend = 0.3, shift = 1 },
      ["iron"] = { target = "frost", blend = 0.08, shift = 1 },
    },
  },
}
