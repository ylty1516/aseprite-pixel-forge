-- rock.lua — 岩石配方：角面石块（小/中/大），带裂缝与苔藓
local function build_rock(px, m, rng, cx, cy, r, angularity, flatten)
  local points = px.rngInt(rng, 6, 8)
  local pts = {}
  for i = 1, points do
    local a = (i - 1) / points * math.pi * 2
    local rr = r * (1 - angularity * rng())
    local x = cx + math.cos(a) * rr
    local y = cy + math.sin(a) * rr * (flatten or 0.8)
    table.insert(pts, {x, y})
  end
  px.polygon(m, pts)
end

local function generate(ctx)
  local px = ctx.px
  local W, H = ctx.size[1], ctx.size[2]
  local p = ctx.params
  local rng = ctx.rng
  local light = ctx.style.lighting

  local ground = H - 2
  local r = ({small = 5, medium = 8, large = 11})[p.size] or 8
  local cx = W / 2 + (rng() - 0.5) * 3
  local cy = ground - r * 0.55

  local m = px.canvas(W, H)
  build_rock(px, m, rng, cx, cy, r, p.angularity, 0.78)
  -- 次级碎石
  if p.secondary then
    local side = (rng() < 0.5) and -1 or 1
    build_rock(px, m, rng,
      cx + side * r * px.rngRange(rng, 0.8, 1.1),
      ground - r * px.rngRange(rng, 0.12, 0.3),
      r * px.rngRange(rng, 0.28, 0.45), p.angularity, 0.7)
  end
  -- 底部贴地压平
  for x = 0, W - 1 do m[ground + 1][x] = false end
  px.despike(m)

  local img = px.newImage(W, H)
  local stone = px.rampOf(ctx.style, p.palette or "stone")
  px.paintShaded(img, m, stone, {light = light, rng = rng, jitter = true, jitterChance = 0.3, levelShift = -1})

  -- 棱面刻线：从顶部向下 2-4 条裂缝
  if p.cracks then
    local cracks = px.rngInt(rng, 2, 4)
    for _ = 1, cracks do
      local x0 = cx + (rng() - 0.5) * r * 1.2
      local y0 = cy - r * px.rngRange(rng, 0.2, 0.7)
      local x1 = x0 + (rng() - 0.5) * r * 0.8
      local y1 = y0 + px.rngRange(rng, r * 0.4, r * 0.9)
      px.carve(img, m, x0, y0, x1, y1, stone, {level = 1})
    end
  end
  -- 顶部亮面：少量高光点
  local glints = px.rngInt(rng, 2, 5)
  for _ = 1, glints do
    local gx = cx + (rng() - 0.5) * r * 1.1
    local gy = cy - r * px.rngRange(rng, 0.3, 0.75)
    if px.get(m, gx, gy) then
      img:putPixel(math.floor(gx), math.floor(gy), stone[#stone])
    end
  end

  -- 苔藓（顶部偏多）
  if p.moss > 0.05 then
    local moss = px.rampOf(ctx.style, "moss")
    local count = math.floor(2 + p.moss * 10)
    px.speckle(img, m, moss, rng, {count = count, size = 1, levels = {2, 3, 4}})
  end

  px.outline(img, m, ctx.style.outline.color, {
    policy = ctx.style.outline.policy, light = light, rng = rng,
  })
  return {img = img, mask = m}
end

return {
  name = "rock",
  category = "nature",
  size = {34, 28},
  params = {
    size = {type = "choice", values = {"small", "medium", "large"}, default = "medium"},
    angularity = {type = "float", min = 0.15, max = 0.55, default = 0.35},
    cracks = {type = "bool", default = true},
    secondary = {type = "bool", default = true},
    moss = {type = "float", min = 0, max = 1, default = 0.4},
    palette = {type = "choice", values = {"stone", "stone_warm"}, default = "stone"},
  },
  generate = generate,
}
