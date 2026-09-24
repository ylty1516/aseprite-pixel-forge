-- 钢铁巨构平原：白日远景（史诗巨构·逆光剪影）/ 中景（死亡搁浅式干草原）/ 近景（玩家行走地图）
-- 渲染：forge scene scenes/steel-plains-day.lua --out <目录> --frames 8 --gif
return {
  name = "steel-plains-day",
  size = { 640, 270 },
  seed = 20260924,
  frames = 8,
  fps = 8,
  time = "day",

  layers = {
    -- 天：浅蓝灰（上深下浅）+ 云带
    { type = "sky", ramp = "frost", from = 3, to = 5 },
    { type = "clouds", count = 3, y0 = 26, y1 = 70, ramp = "bone", density = 0.3,
      wmin = 30, wmax = 60, hmin = 4, hmax = 9 },

    -- 日轮压在巨构天脚线（逆光：远层巨构会从日面前穿过）
    { type = "moon", x = 468, y = 84, r = 17, glow = 46, corrupt = false, ramp = "bone" },
    { type = "rays", x = 468, y = 84, angle = 2.1, spread = 0.6, count = 3,
      length = 220, strength = 0.13, ramp = "bone", level_base = 3, flicker = 0.08 },

    -- ═══ 层一：超巨型剪影（顶部越过画框 → 史诗尺度）═══
    { type = "megastructure", y = 172, hmin = 130, hmax = 240,
      wmin = 14, wmax = 28, gapmin = 36, gapmax = 84,
      ramp = "iron", level = 1, colossal = true, colossal_prob = 0.45,
      colossal_scale = 1.6, styles = { "frame", "tower", "arcology", "tank" } },
    -- 远层整体大气透视（按距离均匀发灰，不按高度）
    { type = "grade", spec = {
      ["iron"] = { target = "frost", blend = 0.62, shift = 2 },
    } },

    -- 跨天际悬索（层一之间）
    { type = "cables", x0 = -30, x1 = 300, y0 = 42, y1 = 46, sag = 30,
      ramp = "iron", level = 2 },
    { type = "cables", x0 = 330, x1 = 670, y0 = 52, y1 = 40, sag = 26,
      ramp = "iron", level = 2 },

    -- ═══ 层二：中景巨构（骨架塔/龙门吊为主）═══
    { type = "megastructure", y = 182, hmin = 64, hmax = 126,
      wmin = 10, wmax = 22, gapmin = 20, gapmax = 48,
      ramp = "iron", level = 2,
      styles = { "frame", "tower", "gantry", "frame", "arcology" } },
    { type = "fog", ramp = "frost", y0 = 148, strength = 0.3, baseLevel = 4, levelSpan = 1 },

    -- 鸟群（尺度参照，逆光剪影）
    { type = "birds", flocks = 2, x0 = 60, x1 = 560, y0 = 54, y1 = 132,
      ramp = "shadow", level = 2 },

    -- 近景悬索（低，带吊杆）
    { type = "cables", x0 = 120, x1 = 640, y0 = 128, y1 = 118, sag = 18,
      ramp = "iron", level = 2, hangers = 22, hanger_len = 3 },

    -- ═══ 层三：近层巨构（细节最实）═══
    { type = "megastructure", y = 190, hmin = 34, hmax = 78,
      wmin = 8, wmax = 18, gapmin = 24, gapmax = 56,
      ramp = "iron", level = 3,
      styles = { "tower", "arcology", "gantry", "frame", "tower" } },
    { type = "fog", ramp = "frost", y0 = 176, strength = 0.16, baseLevel = 4, levelSpan = 1 },

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

    -- 日间调色：草→枯橄榄提亮，土路暖，巨构褪入大气
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
      ["iron"] = { target = "frost", blend = 0.1, shift = 1 },
    },
  },
}
