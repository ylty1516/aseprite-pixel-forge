-- 钢铁巨构平原：白日远景（钢铁巨构）/ 中景（死亡搁浅式枯橄榄丘陵草地）/ 近景（玩家行走地图）
-- 渲染：forge scene scenes/steel-plains-day.lua --out <目录> --frames 8 --gif
return {
  name = "steel-plains-day",
  size = { 640, 270 },
  seed = 20260924,
  frames = 8,
  fps = 8,
  time = "day",

  layers = {
    -- 天：浅蓝灰（上深下浅）+ 云带 + 淡白日轮
    { type = "sky", ramp = "frost", from = 3, to = 5 },
    { type = "clouds", count = 3, y0 = 28, y1 = 64, ramp = "bone", density = 0.3,
      wmin = 30, wmax = 64, hmin = 4, hmax = 9 },
    { type = "moon", x = 522, y = 50, r = 14, glow = 34, corrupt = false, ramp = "bone" },
    { type = "rays", x = 522, y = 50, angle = 2.05, spread = 0.6, count = 3,
      length = 230, strength = 0.14, ramp = "bone", level_base = 3, flicker = 0.08 },

    -- 远景：钢铁巨构（层一：高、细、稀，被雾按入大气）
    { type = "megastructure", y = 168, hmin = 45, hmax = 110, wmin = 8, wmax = 18,
      gapmin = 14, gapmax = 38, ramp = "iron", level = 2,
      frame_prob = 0.25, antenna_prob = 0.5, crane_prob = 0.3 },
    { type = "fog", ramp = "frost", y0 = 118, strength = 0.45, baseLevel = 4, levelSpan = 1 },

    -- 远景：钢铁巨构（层二：矮、近一档）
    { type = "megastructure", y = 182, hmin = 24, hmax = 56, wmin = 7, wmax = 14,
      gapmin = 18, gapmax = 44, ramp = "iron", level = 3,
      frame_prob = 0.15, antenna_prob = 0.35, crane_prob = 0.15 },
    { type = "fog", ramp = "frost", y0 = 152, strength = 0.3, baseLevel = 4, levelSpan = 1 },

    -- 中景：枯橄榄色平滑丘陵（远浅近深）
    { type = "hills", y = 196, amplitude = 9, ramp = "foliage_dead", level = 4 },
    { type = "hills", y = 207, amplitude = 6, ramp = "foliage_dead", level = 3 },
    { type = "fog", ramp = "frost", y0 = 200, strength = 0.22, baseLevel = 4, levelSpan = 1 },

    -- 近景（玩家行走的地图）：草地为主 + 底边土路
    { type = "ground", folder = "tiles", tiles = { "grass_01", "grass_02", "tile_02" }, y = 208 },
    { type = "ground", folder = "tiles", tiles = { "tile_01", "tile_05" }, y = 254 },

    -- 物件：礫石（中景）+ 草簇（动画·风）+ 野花 + 残迹
    { type = "sprite", folder = "rocks", name = "rock_07", x = 96, y = 214 },
    { type = "sprite", folder = "rocks", name = "rock_05", x = 250, y = 213 },
    { type = "sprite", folder = "rocks", name = "rock_08", x = 402, y = 214 },
    { type = "sprite", folder = "rocks", name = "rock_07", x = 560, y = 216 },
    { type = "sprite", folder = "rocks", name = "rock_06", x = 178, y = 252 },
    { type = "sprite", folder = "rocks", name = "rock_02", x = 470, y = 251 },
    { type = "sprite", folder = "flowers", name = "wind_01", x = 62, y = 244 },
    { type = "sprite", folder = "flowers", name = "wind_02", x = 150, y = 250 },
    { type = "sprite", folder = "flowers", name = "wind_03", x = 300, y = 242 },
    { type = "sprite", folder = "flowers", name = "wind_01", x = 118, y = 222 },
    { type = "sprite", folder = "flowers", name = "wind_03", x = 480, y = 224 },
    { type = "sprite", folder = "flowers", name = "wind_01", x = 356, y = 268 },
    { type = "sprite", folder = "flowers", name = "wind_02", x = 520, y = 248 },
    { type = "sprite", folder = "flowers", name = "flower_05", x = 232, y = 246 },
    { type = "sprite", folder = "flowers", name = "flower_02", x = 430, y = 245 },
    { type = "sprite", folder = "ruins", name = "ruin_02", x = 588, y = 248 },

    -- 日间调色：草→枯橄榄提亮，土路暖，岩石冷亮，黑影轻提
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
      ["stone"] = { target = "frost", blend = 0.22, shift = 1 },
      ["stone_warm"] = { target = "bone", blend = 0.18, shift = 1 },
      ["soil"] = { target = "stone_warm", blend = 0.5, shift = 1 },
      ["bark"] = { target = "stone_warm", blend = 0.35, shift = 1 },
      ["wood_dead"] = { target = "stone_warm", blend = 0.3, shift = 1 },
      ["iron"] = { target = "frost", blend = 0.5, shift = 1 },
    },
  },
}
