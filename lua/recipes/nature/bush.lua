-- bush.lua — 灌木/矮丛配方
-- 结构：枯枝（先画，被主体遮挡）→ 主体团簇 → 明暗/纹理 → 浆果/花点 → 轮廓
local function generate(ctx)
  local px = ctx.px
  local W, H = ctx.size[1], ctx.size[2]
  local p = ctx.params
  local rng = ctx.rng
  local light = ctx.style.lighting

  local ground = H - 1
  local cx = W / 2 + (rng() - 0.5) * 3
  local r = p.size

  -- 1) 主体 mask
  local m = px.canvas(W, H)
  px.blob(m, rng, cx, ground - r * 0.55, r, {
    irregularity = 0.5, points = px.rngInt(rng, 8, 12), smooth = 1,
  })
  local lobes = px.rngInt(rng, 1, 3)
  for _ = 1, lobes do
    local side = (rng() < 0.5) and -1 or 1
    px.blob(m, rng,
      cx + side * r * px.rngRange(rng, 0.4, 0.9),
      ground - r * px.rngRange(rng, 0.2, 0.6),
      r * px.rngRange(rng, 0.4, 0.7),
      {irregularity = 0.55, points = 8, smooth = 1})
  end
  -- 贴地压平
  for x = 0, W - 1 do m[ground][x] = false end
  -- 内部小孔
  local holes = px.rngInt(rng, 2, 4)
  for _ = 1, holes do
    local hx = cx + (rng() - 0.5) * r * 1.6
    local hy = ground - r * px.rngRange(rng, 0.3, 1.0)
    px.set(m, hx, hy, false)
    if rng() < 0.5 then px.set(m, hx + 1, hy, false) end
  end
  px.despike(m)

  -- 2) 枯枝 mask（从两侧斜向刺出，短而自然）
  local twig = px.canvas(W, H)
  if p.twigs then
    local count = px.rngInt(rng, 2, 3)
    for _ = 1, count do
      local side = (rng() < 0.5) and -1 or 1
      local tx = cx + side * r * px.rngRange(rng, 0.25, 0.7)
      local ty = ground - r * px.rngRange(rng, 0.5, 0.95)
      local ex = tx + side * px.rngRange(rng, 2.5, 5)
      local ey = ty - px.rngRange(rng, 1.5, 3.5)
      px.lineMask(twig, tx, ty, ex, ey, 1)
    end
  end

  -- 3) 绘制：枯枝先画，主体后画覆盖
  local img = px.newImage(W, H)
  local wood = px.rampOf(ctx.style, "wood_dead")
  if p.twigs then
    px.flatten(img, twig, wood, 2)
  end

  local leaf = px.rampOf(ctx.style, p.palette or "moss")
  px.paintShaded(img, m, leaf, {light = light, rng = rng, jitter = true, jitterChance = 0.4})
  px.clusterJitter(img, m, leaf, rng, {chance = 0.35})
  px.speckle(img, m, leaf, rng, {count = 10, levels = {4, 5}, size = 1})
  px.speckle(img, m, leaf, rng, {count = 6, levels = {1}, size = 1})

  -- 4) 浆果 / 花点
  if p.berries then
    local berry = px.rampOf(ctx.style, p.glow and "ember" or "frost")
    local dots = px.rngInt(rng, 3, 6)
    for _ = 1, dots do
      local bx = math.floor(cx + (rng() - 0.5) * r * 1.6)
      local by = math.floor(ground - r * px.rngRange(rng, 0.45, 1.1))
      if px.get(m, bx, by) then
        img:putPixel(bx, by, berry[#berry])
        if rng() < 0.6 then img:putPixel(bx, by - 1, berry[#berry - 1]) end
      end
    end
  end

  -- 5) 轮廓（主体 ∪ 枯枝）
  local union = px.canvas(W, H)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      union[y][x] = m[y][x] or twig[y][x]
    end
  end
  px.outline(img, union, ctx.style.outline.color, {
    policy = ctx.style.outline.policy, light = light, rng = rng,
  })
  return {img = img, mask = union}
end

return {
  name = "bush",
  category = "nature",
  size = {30, 24},
  params = {
    size = {type = "float", min = 5, max = 9, default = 7},
    palette = {type = "choice", values = {"moss", "foliage_dark", "foliage_dead"},
               default = "moss"},
    twigs = {type = "bool", default = true},
    berries = {type = "bool", default = true},
    glow = {type = "bool", default = false},
  },
  generate = generate,
}
