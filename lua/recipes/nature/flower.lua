-- flower.lua — 草簇 / 墓地百合 / 蕨类
local function blade(px, m, rng, x0, y0, len, curve)
  local x1 = x0 + curve
  local y1 = y0 - len
  local mx = x0 + curve * 0.25
  local my = y0 - len * 0.62
  px.lineMask(m, x0, y0, mx, my, 1)
  px.lineMask(m, mx, my, x1, y1, 1)
  return x1, y1
end

local function generate(ctx)
  local px = ctx.px
  local W, H = ctx.size[1], ctx.size[2]
  local p = ctx.params
  local rng = ctx.rng
  local light = ctx.style.lighting

  local ground = H - 1
  local base_x = W / 2 + (rng() - 0.5) * 3

  local m = px.canvas(W, H)
  local tips = {}
  local leaf = px.rampOf(ctx.style, p.palette or "foliage_dark")

  if p.kind == "fern" then
    -- 蕨：中轴上对生小叶
    local len = px.rngRange(rng, 10, 15)
    local x_top = base_x + (rng() - 0.5) * 2
    px.lineMask(m, base_x, ground - 1, x_top, ground - 1 - len, 1)
    local pairs = math.floor(len / 2.2)
    for i = 1, pairs do
      local t = i / pairs
      local sx = base_x + (x_top - base_x) * t
      local sy = ground - 1 - len * t
      local ll = (1 - t) * 4 + 1.5
      px.lineMask(m, sx, sy, sx - ll, sy - ll * 0.35, 1)
      px.lineMask(m, sx, sy, sx + ll, sy - ll * 0.35, 1)
    end
    table.insert(tips, {x_top, ground - 1 - len})
  else
    local count = math.floor(p.count)
    for i = 1, count do
      local frac = (i - 0.5) / count            -- 0..1，均匀分布
      local side = (frac < 0.5) and -1 or 1
      local spread = math.abs(frac - 0.5) * 2    -- 0中心..1边缘
      local x0 = base_x + (frac - 0.5) * 6 + (rng() - 0.5) * 1.2
      local len = px.rngRange(rng, p.height * (0.55 + spread * 0.25), p.height)
      -- 向外弯（扇形展开）
      local curve = side * (1.2 + spread * 2.6) + (rng() - 0.5) * 1.2
      local tx, ty = blade(px, m, rng, x0, ground, math.floor(len), curve)
      table.insert(tips, {tx, ty, len})
    end
  end
  px.despike(m)

  local img = px.newImage(W, H)
  px.paintShaded(img, m, leaf, {light = light, rng = rng, jitter = true, jitterChance = 0.25})

  -- 叶尖提亮
  for _, t in ipairs(tips) do
    local tx, ty = math.floor(t[1]), math.floor(t[2])
    for dy = 0, 1 do
      if px.get(m, tx, ty + dy) then img:putPixel(tx, ty + dy, leaf[#leaf]) end
    end
  end

  -- 百合花 / 花苞：开在最高的 1-3 根叶尖上
  if p.kind == "lily" then
    table.sort(tips, function(a, b) return (a[3] or 0) > (b[3] or 0) end)
    local flowers = math.min(#tips, px.rngInt(rng, 1, 2))
    local petal = px.rampOf(ctx.style, "frost")
    local heart = px.rampOf(ctx.style, p.glow and "ember" or "frost")
    local heart_level = p.glow and 4 or #heart
    local function petal_px(x, y, c)
      if px.inside(m, x, y) then
        img:putPixel(x, y, c)
        m[y][x] = true  -- 花瓣并入轮廓，确保描边包住
      end
    end
    for i = 1, flowers do
      local tx, ty = math.floor(tips[i][1]), math.floor(tips[i][2])
      -- 三瓣小花：上/左上/右上 + 亮心（整体 3px 宽，避免蘑菇感）
      petal_px(tx, ty - 1, petal[#petal - 1])
      petal_px(tx - 1, ty - 1, petal[#petal - 1])
      petal_px(tx + 1, ty - 1, petal[#petal - 1])
      petal_px(tx, ty, heart[heart_level])
      -- 花下小叶托
      if px.get(m, tx - 1, ty + 1) then img:putPixel(tx - 1, ty + 1, leaf[2]) end
      if px.get(m, tx + 1, ty + 1) then img:putPixel(tx + 1, ty + 1, leaf[2]) end
    end
  end

  -- 多帧：叶片弯曲摆动（根部固定，梢部摆动最大；花/苔随叶移动）
  if (ctx.params.frames or 1) > 1 then
    local amp = 2.0
    if p.kind == "fern" then amp = 1.0 end
    if p.kind == "tuft" then amp = 2.2 end
    img, m = px.shear(img, m, {
      amp = amp, pivot = ground - 1, phase = ctx.phase or 0, falloff = 1.5,
    })
  end

  px.outline(img, m, ctx.style.outline.color, {
    policy = ctx.style.outline.policy, light = light, rng = rng,
  })
  return {img = img, mask = m}
end

return {
  name = "flower",
  category = "nature",
  size = {26, 24},
  params = {
    kind = {type = "choice", values = {"tuft", "lily", "fern"}, default = "tuft"},
    count = {type = "int", min = 3, max = 8, default = 5},
    height = {type = "int", min = 8, max = 16, default = 12},
    palette = {type = "choice", values = {"foliage_dark", "moss", "foliage_dead"},
               default = "foliage_dark"},
    glow = {type = "bool", default = false},
    frames = {type = "int", min = 1, max = 6, default = 1, sample = false},
  },
  generate = generate,
}
