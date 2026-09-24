-- 钢铁巨构平原·王国画风：剪影 + 渐变天空 + 暖光点 + 湖面倒影
-- 时段：day / dusk / night / bloodmoon（forge scene --time <preset>）
-- 渲染：forge scene scenes/steel-plains-day.lua --out <目录> --frames 8 --gif
return {
  name = "steel-plains-day",
  size = { 640, 270 },
  seed = 20260924,
  frames = 8,
  fps = 8,
  time = "day",

  layers = {
    -- 渐变天（时段换色）：上深下浅
    { type = "sky", ramp = "sky", from = 1, to = 4 },
    { type = "stars", count = 90, ymax = 128, ramp = "frost" },
    -- 地平线暖光带（深暖色高密度柔光）
    { type = "fog", ramp = "ember", strength = 0.42, baseLevel = 3, levelSpan = 1,
      field = function(_, y)
        local d = (y - 164) / 92
        return math.max(0, 1 - d * d)
      end },
    { type = "clouds", count = 3, y0 = 30, y1 = 76, ramp = "sky", density = 0.22,
      wmin = 70, wmax = 150, hmin = 6, hmax = 12, atmo = true },

    { type = "moon", x = 470, y = 92, r = 15, glow = 52, corrupt = false, ramp = "bone" },
    { type = "rays", x = 470, y = 92, angle = 2.15, spread = 0.65, count = 4,
      length = 220, strength = 0.14, ramp = "ember", level_base = 3, flicker = 0.1 },

    -- ═══ 最远层：钢构剪影（shadow[3]，洗入天空）═══
    { type = "viaduct", x0 = -24, x1 = 664, y = 126, deck_h = 5, base = 170,
      broken = true, broken_count = 3, debris = false,
      ramp = "shadow", level = 3, pier_min = 52, pier_max = 96 },
    { type = "megastructure", y = 168, hmin = 96, hmax = 150,
      wmin = 10, wmax = 20, gapmin = 250, gapmax = 440,
      ramp = "shadow", level = 3, colossal = true, colossal_prob = 0.6,
      colossal_scale = 1.75, colossal_width_scale = 1.1,
      styles = { "frame" }, flat = true, glow = true, blink = true },
    -- 远层水彩式洗入天空
    { type = "grade", spec = {
      ["shadow"] = { target = "sky", blend = 0.55, shift = 1 },
    } },
    { type = "fog", ramp = "sky", strength = 0.4, baseLevel = 3, levelSpan = 1, atmo = true,
      field = function(_, y)
        local d = (y - 138) / 58
        return math.max(0, 1 - d * d)
      end },

    -- 高空钢缆
    { type = "cables", x0 = -20, x1 = 340, y0 = 44, y1 = 52, sag = 28,
      ramp = "shadow", level = 3 },
    { type = "cables", x0 = 360, x1 = 670, y0 = 56, y1 = 42, sag = 24,
      ramp = "shadow", level = 3 },

    -- ═══ 湖面：倒影天空与远景钢构（王国标志元素）═══
    { type = "water", y = 172, depth = 32, ramp = "sky", base_level = 2,
      tint = 0.38, darken = 1, wobble = 2, wave_period = 7, sparkle = true },

    -- ═══ 中景：钢构剪影（shadow[2]）+ 暖窗点 + 信标闪烁 ═══
    { type = "megastructure", x0 = 34, x1 = 232, y = 206,
      hmin = 30, hmax = 38, wmin = 72, wmax = 92, gapmin = 300, gapmax = 400,
      ramp = "shadow", level = 2, styles = { "steelhall" }, flat = true, glow = true },
    { type = "megastructure", x0 = 254, x1 = 336, y = 205,
      hmin = 46, hmax = 58, wmin = 52, wmax = 64, gapmin = 300, gapmax = 400,
      ramp = "shadow", level = 2, styles = { "steelarch" }, flat = true, glow = true },
    { type = "megastructure", x0 = 348, x1 = 392, y = 205,
      hmin = 62, hmax = 88, wmin = 12, wmax = 16, gapmin = 300, gapmax = 400,
      ramp = "shadow", level = 2, styles = { "frame" }, flat = true, glow = true, blink = true },
    { type = "megastructure", x0 = 404, x1 = 556, y = 206,
      hmin = 22, hmax = 30, wmin = 70, wmax = 88, gapmin = 300, gapmax = 400,
      ramp = "shadow", level = 2, styles = { "steelhall" }, flat = true, glow = true },
    { type = "megastructure", x0 = 572, x1 = 660, y = 205,
      hmin = 38, hmax = 50, wmin = 48, wmax = 60, gapmin = 300, gapmax = 400,
      ramp = "shadow", level = 2, styles = { "steelarch" }, flat = true, glow = true },
    { type = "fog", ramp = "sky", strength = 0.22, baseLevel = 3, levelSpan = 1, atmo = true,
      field = function(_, y)
        local d = (y - 190) / 34
        return math.max(0, 1 - d * d)
      end },

    { type = "birds", flocks = 2, x0 = 60, x1 = 570, y0 = 54, y1 = 126,
      ramp = "shadow", level = 1 },

    -- 中低空钢缆（带吊杆）
    { type = "cables", x0 = 40, x1 = 640, y0 = 122, y1 = 112, sag = 16,
      ramp = "shadow", level = 2, hangers = 26, hanger_len = 3 },

    -- ═══ 地面：剪影丘陵 + 剪影草地 + 薄雾 ═══
    { type = "hills", y = 198, amplitude = 9, ramp = "shadow", level = 3 },
    { type = "hills", y = 208, amplitude = 6, ramp = "shadow", level = 2 },
    { type = "ground", folder = "tiles", tiles = { "grass_01", "grass_02", "tile_02" }, y = 209 },
    { type = "ground", folder = "tiles", tiles = { "tile_01", "tile_05" }, y = 254 },
    { type = "fog", ramp = "sky", strength = 0.14, baseLevel = 3, levelSpan = 1, atmo = true,
      field = function(_, y)
        local d = (y - 214) / 44
        return math.max(0, 1 - d * d)
      end },

    -- ═══ 近景：巨型钢拱门 + 绗架塔 + 钢骨架（近黑剪影 + 暖点）═══
    { type = "megastructure", x0 = 26, x1 = 196, y = 250,
      hmin = 56, hmax = 66, wmin = 128, wmax = 152, gapmin = 400, gapmax = 500,
      ramp = "shadow", level = 1, styles = { "steelarch" }, flat = true, glow = true },
    { type = "megastructure", x0 = 462, x1 = 502, y = 248,
      hmin = 74, hmax = 96, wmin = 10, wmax = 13, gapmin = 400, gapmax = 500,
      ramp = "shadow", level = 1, styles = { "mast" }, flat = true, glow = true, blink = true },
    { type = "megastructure", x0 = 530, x1 = 648, y = 246,
      hmin = 16, hmax = 22, wmin = 84, wmax = 104, gapmin = 400, gapmax = 500,
      ramp = "shadow", level = 1, styles = { "steelhall" }, flat = true, glow = true },

    -- 物件
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

    -- 王国式日间调色：景物→剪影（近黑），花点（frost）保留
    { type = "grade", preset = "kingdom_day" },

    -- 极少萤火
    { type = "embers", count = 3, x0 = 60, x1 = 600, y0 = 170, y1 = 250,
      rise = 24, ramp = "ember" },
  },

  -- 时段预设：同一剪影，不同天空
  times = {
    day = {
      hide = { "stars" },
      sky_ramp = "sky", sky_from = 1, sky_to = 4,
      fog_ramp = "sky", cloud_ramp = "sky", water_ramp = "sky",
    },
    dusk = {
      hide = { "stars" },
      sky_ramp = "ember", sky_from = 2, sky_to = 4,
      fog_ramp = "ember", cloud_ramp = "ember", water_ramp = "ember",
      moon_ramp = "ember",
    },
    night = {
      sky_ramp = "shadow", sky_from = 2, sky_to = 4,
      fog_ramp = "frost", cloud_ramp = "shadow", water_ramp = "shadow",
      moon_ramp = "frost",
    },
    bloodmoon = {
      sky_ramp = "ember", sky_from = 1, sky_to = 2,
      fog_ramp = "ember", cloud_ramp = "ember", water_ramp = "ember",
      moon_corrupt = true,
    },
  },

  grades = {
    kingdom_day = {
      ["foliage_dark"] = { target = "shadow", blend = 0.92 },
      ["moss"] = { target = "shadow", blend = 0.9 },
      ["foliage_dead"] = { target = "shadow", blend = 0.9 },
      ["stone"] = { target = "shadow", blend = 0.88 },
      ["stone_warm"] = { target = "shadow", blend = 0.88 },
      ["soil"] = { target = "shadow", blend = 0.88 },
      ["bark"] = { target = "shadow", blend = 0.9 },
      ["wood_dead"] = { target = "shadow", blend = 0.9 },
      ["iron"] = { target = "shadow", blend = 0.92 },
    },
  },
}
