-- 钢铁巨构平原：白日远景（死亡搁浅式工程遗迹）/ 中景（干草原）/ 近景（玩家行走地图）
-- 巨构语言：粗野主义混凝土综合体 + 破碎高架桥 + 天线碟 + 绗架通讯塔（非摩天楼群）
-- 渲染：forge scene scenes/steel-plains-day.lua --out <目录> --frames 8 --gif
return {
  name = "steel-plains-day",
  size = { 640, 270 },
  seed = 20260924,
  frames = 8,
  fps = 8,
  time = "day",

  layers = {
    -- 天：阴沉浅灰蓝 + 云带
    { type = "sky", ramp = "frost", from = 3, to = 5 },
    { type = "clouds", count = 3, y0 = 24, y1 = 66, ramp = "bone", density = 0.4,
      wmin = 46, wmax = 110, hmin = 5, hmax = 10 },

    { type = "moon", x = 474, y = 86, r = 16, glow = 42, corrupt = false, ramp = "bone" },
    { type = "rays", x = 474, y = 86, angle = 2.1, spread = 0.6, count = 3,
      length = 200, strength = 0.12, ramp = "bone", level_base = 3, flicker = 0.08 },

    -- ═══ 最远层：横贯全宽的破碎高架桥（雾中遗构）+ 巨型通讯塔剪影 ═══
    { type = "viaduct", x0 = -24, x1 = 664, y = 128, deck_h = 6, base = 200,
      broken = true, broken_count = 3, debris = false,
      ramp = "stone_warm", level = 1, pier_min = 52, pier_max = 96 },
    -- 远层通信塔（越框巨型，保持绗架形制）
    { type = "megastructure", y = 176, hmin = 96, hmax = 150,
      wmin = 7, wmax = 11, gapmin = 130, gapmax = 260,
      ramp = "iron", level = 1, colossal = true, colossal_prob = 0.6,
      colossal_scale = 1.8, colossal_width_scale = 1.0, styles = { "mast" } },
    -- 远层整体大气透视（按距离均匀发灰）
    { type = "grade", spec = {
      ["iron"] = { target = "frost", blend = 0.6, shift = 2 },
      ["stone_warm"] = { target = "frost", blend = 0.42, shift = 1 },
    } },
    { type = "fog", ramp = "frost", y0 = 150, strength = 0.14, baseLevel = 4, levelSpan = 1 },

    -- 高空悬索（远塔之间）
    { type = "cables", x0 = -20, x1 = 340, y0 = 46, y1 = 54, sag = 28,
      ramp = "iron", level = 2 },
    { type = "cables", x0 = 360, x1 = 670, y0 = 58, y1 = 44, sag = 24,
      ramp = "iron", level = 2 },

    -- ═══ 中景：配送中心建筑群（冷灰混凝土）+ 厂房 + 天线碟阵 ═══
    -- 左：主综合体（体积最大，视觉焦点；带大门与屋顶天线碟）
    { type = "megastructure", x0 = 30, x1 = 210, y = 206,
      hmin = 52, hmax = 62, wmin = 92, wmax = 108, gapmin = 300, gapmax = 400,
      ramp = "stone", level = 3, styles = { "block" } },
    -- 中左：长条厂房
    { type = "megastructure", x0 = 226, x1 = 348, y = 206,
      hmin = 20, hmax = 26, wmin = 70, wmax = 84, gapmin = 26, gapmax = 40,
      ramp = "stone", level = 3, styles = { "hall" } },
    -- 中：通讯塔（中景最细高元素）
    { type = "megastructure", x0 = 356, x1 = 388, y = 204,
      hmin = 62, hmax = 84, wmin = 8, wmax = 11, gapmin = 300, gapmax = 400,
      ramp = "iron", level = 2, styles = { "mast" } },
    -- 右：第二组综合体（矮于左组，退后一层）
    { type = "megastructure", x0 = 428, x1 = 660, y = 205,
      hmin = 22, hmax = 34, wmin = 56, wmax = 76, gapmin = 24, gapmax = 40,
      ramp = "stone", level = 3, styles = { "block", "hall", "hall" } },
    { type = "fog", ramp = "frost", y0 = 176, strength = 0.12, baseLevel = 3, levelSpan = 1 },

    -- 鸟群（尺度参照）
    { type = "birds", flocks = 2, x0 = 60, x1 = 570, y0 = 56, y1 = 130,
      ramp = "shadow", level = 2 },

    -- 中低空悬索（带吊杆，连向近景塔）
    { type = "cables", x0 = 60, x1 = 640, y0 = 122, y1 = 112, sag = 16,
      ramp = "iron", level = 2, hangers = 26, hanger_len = 3 },

    -- ═══ 近层：一座绗架通讯塔 + 半埋混凝土块残迹 ═══
    { type = "megastructure", x0 = 76, x1 = 110, y = 210,
      hmin = 64, hmax = 88, wmin = 8, wmax = 11, gapmin = 300, gapmax = 400,
      ramp = "iron", level = 3, styles = { "mast" } },
    { type = "megastructure", x0 = 452, x1 = 560, y = 204,
      hmin = 14, hmax = 20, wmin = 40, wmax = 58, gapmin = 300, gapmax = 400,
      ramp = "stone", level = 3, styles = { "block" } },
    { type = "fog", ramp = "frost", y0 = 184, strength = 0.15, baseLevel = 4, levelSpan = 1 },

    -- 中景：枯橄榄色平滑丘陵（远浅近深）
    { type = "hills", y = 198, amplitude = 9, ramp = "foliage_dead", level = 4 },
    { type = "hills", y = 208, amplitude = 6, ramp = "foliage_dead", level = 3 },
    { type = "fog", ramp = "frost", y0 = 202, strength = 0.2, baseLevel = 4, levelSpan = 1 },

    -- 近景（玩家行走的地图）：草地为主 + 底边土路
    { type = "ground", folder = "tiles", tiles = { "grass_01", "grass_02", "tile_02" }, y = 209 },
    { type = "ground", folder = "tiles", tiles = { "tile_01", "tile_05" }, y = 254 },

    -- 物件：礫石（中景）+ 草簇（动画·风）+ 野花 + 混凝土残骸（砖堆）
    { type = "sprite", folder = "rocks", name = "rock_07", x = 96, y = 215 },
    { type = "sprite", folder = "rocks", name = "rock_05", x = 250, y = 214 },
    { type = "sprite", folder = "rocks", name = "rock_08", x = 402, y = 215 },
    { type = "sprite", folder = "rocks", name = "rock_07", x = 560, y = 217 },
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
    { type = "sprite", folder = "ruins", name = "ruin_02", x = 300, y = 250 },
    { type = "sprite", folder = "ruins", name = "ruin_04", x = 588, y = 250 },

    -- 日间调色：草→枯橄榄提亮，混凝土偏暖白，钢铁褪入大气
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
