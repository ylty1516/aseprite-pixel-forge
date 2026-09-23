-- tile.lua — 32×32 地形 tile：草地 / 泥路 / 石板路 / 石地
-- 注：tile 满画布、不做轮廓（outline policy = none），允许触边。
local function paint_grass(px, ctx, img, m)
  local rng = ctx.rng
  local ramp = px.rampOf(ctx.style, "foliage_dark")
  local p = ctx.params
  px.ditherFill(img, m, ramp, 2, 3, {density = 0.35 + p.density * 0.3})
  -- 短草茎
  local strokes = math.floor(30 + p.density * 50)
  for _ = 1, strokes do
    local x = px.rngInt(rng, 0, 31)
    local y = px.rngInt(rng, 1, 31)
    local len = px.rngInt(rng, 1, 3)
    for i = 0, len - 1 do
      if y - i >= 0 then
        img:putPixel(x, y - i, ramp[px.rngInt(rng, 3, 5)])
      end
    end
    if rng() < 0.5 and x + 1 <= 31 then
      img:putPixel(x + 1, y, ramp[3])
    end
  end
  -- 暗斑（轻微，避免黑洞）
  px.speckle(img, m, ramp, rng, {count = 2, size = 1, levels = {2}})
end

local function paint_dirt(px, ctx, img, m)
  local rng = ctx.rng
  local ramp = px.rampOf(ctx.style, "soil")
  local p = ctx.params
  px.ditherFill(img, m, ramp, 2, 3, {density = 0.4 + p.density * 0.3})
  -- 碎石（簇状，少而可见）
  local pebbles = math.floor(4 + p.density * 6)
  for _ = 1, pebbles do
    local x = px.rngInt(rng, 0, 30)
    local y = px.rngInt(rng, 0, 30)
    img:putPixel(x, y, ramp[1])
    if rng() < 0.7 then img:putPixel(x + 1, y, ramp[2]) end
    if rng() < 0.5 then img:putPixel(x, y + 1, ramp[2]) end
    if rng() < 0.35 then img:putPixel(x + 1, y + 1, ramp[2]) end
  end
  -- 亮点砂砾
  for _ = 1, px.rngInt(rng, 3, 8) do
    img:putPixel(px.rngInt(rng, 0, 31), px.rngInt(rng, 0, 31), ramp[4])
  end
  -- 零星草芽
  local grass = px.rampOf(ctx.style, "foliage_dark")
  for _ = 1, px.rngInt(rng, 0, 4) do
    local x = px.rngInt(rng, 1, 30)
    local y = px.rngInt(rng, 2, 31)
    img:putPixel(x, y, grass[3])
    img:putPixel(x, y - 1, grass[4])
  end
end

local function rounded_rect(img, px, ramp, light, x0, y0, x1, y1, rng)
  local stone = px.canvas(32, 32)
  px.rect(stone, x0, y0, x1, y1)
  if x1 - x0 >= 2 and y1 - y0 >= 2 then
    px.set(stone, x0, y0, false); px.set(stone, x1, y0, false)
    px.set(stone, x0, y1, false); px.set(stone, x1, y1, false)
  end
  px.paintShaded(img, stone, ramp, {light = light, rng = rng, jitter = true, jitterChance = 0.2, levelShift = -1})
  return stone
end

local function paint_cobble(px, ctx, img, m, ramp)
  local rng = ctx.rng
  -- 底：灰浆
  px.flatten(img, m, ramp, 1)
  local row_h = 8
  local rows = 4
  local all_stones = px.canvas(32, 32)
  for row = 0, rows - 1 do
    local y0 = row * row_h
    local y1 = y0 + row_h - 2
    local offset = (row % 2 == 0) and 0 or -5
    local x = offset - 6
    while x < 32 do
      local w = px.rngInt(rng, 6, 11)
      local stone = rounded_rect(img, px, ramp, ctx.style.lighting,
        math.max(0, x), y0, math.min(31, x + w), y1, rng)
      for yy = 0, 31 do
        for xx = 0, 31 do
          if stone[yy][xx] then all_stones[yy][xx] = true end
        end
      end
      x = x + w + 2
    end
  end
  px.clusterJitter(img, m, ramp, rng, {chance = 0.15})
  -- 石缝苔藓
  local moss = px.rampOf(ctx.style, "moss")
  px.speckle(img, all_stones, moss, rng, {count = math.floor(2 + ctx.params.moss * 8),
    size = 1, levels = {2, 3}})
end

local function paint_stone_floor(px, ctx, img, m, ramp)
  local rng = ctx.rng
  px.flatten(img, m, ramp, 1)
  -- 2x2 大石板（每块独立明暗）
  for gy = 0, 1 do
    for gx = 0, 1 do
      local slab = px.canvas(32, 32)
      px.rect(slab, gx * 16 + 1, gy * 16 + 1, gx * 16 + 14, gy * 16 + 14)
      -- 边角损伤
      px.perturb(slab, rng, 0.06)
      px.paintShaded(img, slab, ramp, {light = ctx.style.lighting, rng = rng, jitter = true, levelShift = -1})
      -- 裂纹
      if rng() < 0.6 then
        local x0 = gx * 16 + px.rngInt(rng, 4, 12)
        px.carve(img, slab, x0, gy * 16 + 2, x0 + px.rngInt(rng, -4, 4), gy * 16 + 14,
          ramp, {level = 1})
      end
    end
  end
  -- 缝隙苔藓
  local moss = px.rampOf(ctx.style, "moss")
  px.speckle(img, m, moss, rng, {count = math.floor(2 + ctx.params.moss * 6),
    size = 1, levels = {1, 2}})
end

local function generate(ctx)
  local px = ctx.px
  local W, H = ctx.size[1], ctx.size[2]
  local p = ctx.params
  local rng = ctx.rng

  local m = px.canvas(W, H)
  px.rect(m, 0, 0, W - 1, H - 1)

  local img = px.newImage(W, H)
  if p.kind == "grass" then
    paint_grass(px, ctx, img, m)
  elseif p.kind == "dirt" then
    paint_dirt(px, ctx, img, m)
  elseif p.kind == "cobble" then
    paint_cobble(px, ctx, img, m, px.rampOf(ctx.style, p.palette or "stone"))
  else
    paint_stone_floor(px, ctx, img, m, px.rampOf(ctx.style, p.palette or "stone"))
  end
  -- tile 不描边
  return {img = img, mask = m}
end

return {
  name = "tile",
  category = "nature",
  size = {32, 32},
  params = {
    kind = {type = "choice", values = {"grass", "dirt", "cobble", "stone_floor"},
            default = "grass"},
    density = {type = "float", min = 0, max = 1, default = 0.5},
    moss = {type = "float", min = 0, max = 1, default = 0.4},
    palette = {type = "choice", values = {"stone", "stone_warm"}, default = "stone"},
  },
  generate = generate,
}
