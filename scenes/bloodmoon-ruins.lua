-- 血月废墟：哥特教堂遗迹夜景（《王国》式大气光影 keynote）
-- 时段预设：day / dawn / dusk / night / bloodmoon（forge scene --time <preset>）
return {
  name = "bloodmoon-ruins",
  size = { 640, 270 },
  seed = 20260923,
  frames = 8,
  fps = 8,
  time = "bloodmoon",

  layers = {
    { type = "sky", ramp = "shadow", from = 1, to = 3 },
    { type = "stars", count = 90, ymax = 132, ramp = "frost" },
    { type = "moon", x = 470, y = 64, r = 26, glow = 30, corrupt = true },

    { type = "ridge", y = 138, amplitude = 34, ramp = "shadow", level = 2 },
    { type = "treeline", y = 198, height = 15, ramp = "shadow", level = 1 },

    { type = "ground", folder = "tiles", tiles = { "tile_02", "grass_01", "grass_02" }, y = 204 },

    -- 中景遗迹：断柱 + 拱残件（叙事焦点）
    { type = "sprite", folder = "ruins", name = "ruin_07", x = 336, y = 208 },
    { type = "sprite", folder = "ruins", name = "ruin_01", x = 206, y = 252 },
    { type = "sprite", folder = "ruins", name = "ruin_04", x = 428, y = 242 },
    -- 树木
    { type = "sprite", folder = "trees", name = "tree_04", x = 116, y = 230 },
    { type = "sprite", folder = "trees", name = "tree_05", x = 566, y = 236 },
    { type = "sprite", folder = "trees", name = "tree_07", x = 262, y = 216 },

    -- 时段调色（血月：压暗 + 冷紫，余烬点缀）
    { type = "grade", preset = "bloodmoon" },

    -- 火把光池：内核亮、边缘柔、地面透视椭圆；暖色仅限芯部
    { type = "light", x = 206, y = 222, r = 44, core_r = 13, strength = 1.05,
      core_strength = 0.95, squash = 1.7, falloff = 3.4, flicker = 0.26,
      warm = true, warm_target = "ember", warm_blend = 0.34, warm_r = 22, flame = true },
    { type = "light", x = 428, y = 226, r = 27, core_r = 9, strength = 0.85,
      core_strength = 0.8, squash = 1.7, falloff = 3.4, flicker = 0.32,
      warm = true, warm_target = "ember", warm_blend = 0.3, warm_r = 15, flame = true, phase = 1.7 },

    -- 低层雾（薄）
    { type = "fog", ramp = "frost", y0 = 216, strength = 0.15, baseLevel = 2, levelSpan = 1 },

    -- 血月洒下的血色光束（淡、宽、微闪）
    { type = "rays", x = 470, y = 64, angle = 1.72, spread = 0.65, count = 4,
      length = 240, strength = 0.27, flicker = 0.25, ramp = "ember" },

    -- 余烬粒子：只集中在两处火把附近，少量飘散
    { type = "embers", count = 5, x0 = 178, x1 = 238, y0 = 150, y1 = 240, rise = 34 },
    { type = "embers", count = 3, x0 = 406, x1 = 452, y0 = 160, y1 = 232, rise = 30 },
    { type = "embers", count = 2, x0 = 300, x1 = 620, y0 = 70, y1 = 130, rise = 46 },

    -- 前景剪影（框景纵深）
    { type = "fg_band", y = 256, amplitude = 5, level = 1, density = 0.92 },
  },

  -- 时段变体：forge scene --time <preset>
  times = {
    day = {
      sky_ramp = "frost", sky_from = 3, sky_to = 5,
      hide = { "stars", "moon", "light", "rays", "embers" },
      grade = "day", fog_strength = 0.1,
    },
    dawn = {
      sky_ramp = "frost", sky_from = 2, sky_to = 4,
      hide = { "stars", "moon", "rays", "embers" },
      grade = "dawn", fog_strength = 0.18,
    },
    dusk = {
      sky_ramp = "shadow", sky_from = 2, sky_to = 4,
      moon_corrupt = false,
      hide = { "stars", "rays" },
      grade = "dusk", fog_strength = 0.2,
    },
    night = {
      moon_corrupt = false,
      hide = { "rays" },
      grade = "night", fog_strength = 0.15,
    },
    bloodmoon = {
      moon_corrupt = true,
      grade = "bloodmoon",
    },
  },

  grades = {
    day = {},
    dawn = {
      ["shadow"] = { target = "frost", blend = 0.16 },
      ["stone"] = { target = "frost", blend = 0.14 },
      ["foliage_dark"] = { target = "moss", blend = 0.22 },
      ["stone_warm"] = { target = "ember", blend = 0.12 },
      ["frost"] = { target = "ember", blend = 0.18 },
    },
    dusk = {
      ["shadow"] = { target = "stone_warm", blend = 0.14 },
      ["stone"] = { target = "stone_warm", blend = 0.34 },
      ["stone_warm"] = { target = "ember", blend = 0.2 },
      ["foliage_dark"] = { target = "foliage_dead", blend = 0.4 },
      ["moss"] = { target = "foliage_dead", blend = 0.45 },
      ["frost"] = { target = "ember", blend = 0.4 },
      ["bark"] = { target = "ember", blend = 0.25 },
      ["soil"] = { target = "stone_warm", blend = 0.22 },
    },
    night = {
      ["foliage_dark"] = { target = "shadow", blend = 0.6 },
      ["moss"] = { target = "shadow", blend = 0.65 },
      ["stone"] = { target = "shadow", blend = 0.45 },
      ["stone_warm"] = { target = "shadow", blend = 0.5 },
      ["bark"] = { target = "wood_dead", blend = 0.5 },
      ["soil"] = { target = "shadow", blend = 0.6 },
      ["frost"] = { target = "shadow", blend = 0.3 },
    },
    bloodmoon = {
      ["foliage_dark"] = { target = "shadow", blend = 0.8 },
      ["moss"] = { target = "shadow", blend = 0.85 },
      ["foliage_dead"] = { target = "shadow", blend = 0.75 },
      ["stone"] = { target = "shadow", blend = 0.55 },
      ["stone_warm"] = { target = "shadow", blend = 0.6 },
      ["bark"] = { target = "wood_dead", blend = 0.6 },
      ["wood_dead"] = { target = "shadow", blend = 0.5 },
      ["soil"] = { target = "shadow", blend = 0.75 },
      ["iron"] = { target = "shadow", blend = 0.5 },
      ["bone"] = { target = "shadow", blend = 0.35 },
      ["frost"] = { target = "ember", blend = 0.5 },
    },
  },
}
