-- tree.lua — 树木配方：阔叶树 / 枯树 / 松柏
local function draw_trunk(px, m, rng, W, H, p)
  local base_y = H - 2
  local cx = W / 2 + (rng() - 0.5) * 2
  local trunk_h = p.height * (1 - p.canopy)
  local trunk_top = base_y - trunk_h
  local lean = p.lean or 0.08
  local x_top = cx + lean * trunk_h

  local steps = 7
  for i = 0, steps do
    local t = i / steps
    local x = cx + (x_top - cx) * t
    local y = base_y - trunk_h * t
    local r = (2.6 - 1.4 * t) / 2 + 0.3
    px.disk(m, x, y, r, r)
  end

  -- 根部外扩（短小，不交叉）
  px.lineMask(m, cx - 3, base_y - 1, cx - 2, base_y, 1)
  px.lineMask(m, cx + 3, base_y - 1, cx + 2, base_y, 1)

  -- 枯树：裸露的角状枝杈（细、上扬、带锥度）
  if p.kind == "dead" then
    local branch_count = px.rngInt(rng, 2, 4)
    for i = 1, branch_count do
      local t = 0.25 + (i - 1) / branch_count * 0.55 + rng() * 0.1
      local bx = cx + (x_top - cx) * t
      local by = base_y - trunk_h * t
      local dir = (i % 2 == 0) and 1 or -1
      local len = px.rngRange(rng, 5, 10)
      local ex = bx + dir * len * px.rngRange(rng, 0.7, 1.1)
      local ey = by - len * px.rngRange(rng, 0.6, 1.0)
      local mx, my = bx + (ex - bx) * 0.45, by + (ey - by) * 0.45
      px.lineMask(m, bx, by, mx, my, 2)
      px.lineMask(m, mx, my, ex, ey, 1)
      -- 次级细杈（从 60% 处）
      local sx, sy = bx + (ex - bx) * 0.6, by + (ey - by) * 0.6
      px.lineMask(m, sx, sy, sx + dir * px.rngRange(rng, 1.5, 3.5),
        sy - px.rngRange(rng, 2, 4.5), 1)
    end
  end
  return cx, base_y, x_top, trunk_top
end

local function draw_canopy(px, m, rng, W, H, p, cx, trunk_top)
  local canopy_r = p.height * p.canopy * 0.78
  local cy = trunk_top - canopy_r * 0.35
  local blobs = px.rngInt(rng, 4, 6)
  local span = canopy_r * 1.4
  for i = 1, blobs do
    local a = (i / blobs) * math.pi * 2 + rng() * 0.8
    local bx = cx + math.cos(a) * span * 0.7 * px.rngRange(rng, 0.5, 1.1)
    local by = cy + math.sin(a) * span * 0.45 * px.rngRange(rng, 0.4, 1.0)
    bx = bx + (rng() - 0.5) * p.asymmetry * 6
    local r = canopy_r * px.rngRange(rng, 0.55, 0.95)
    px.blob(m, rng, bx, math.max(3, by), r, {
      irregularity = 0.55, points = px.rngInt(rng, 8, 12), smooth = 1,
    })
  end
  px.blob(m, rng, cx, cy, canopy_r * 0.85, {
    irregularity = 0.4, points = 10, smooth = 1,
  })
  -- 透光孔洞（树冠不是实心球）
  local holes = px.rngInt(rng, 3, 6)
  for _ = 1, holes do
    local hx = cx + (rng() - 0.5) * canopy_r * 2.4
    local hy = cy + (rng() - 0.5) * canopy_r * 1.6
    local hr = px.rngRange(rng, 0.8, 1.9)
    local y0 = math.max(0, math.floor(hy - hr))
    local y1 = math.min(H - 1, math.ceil(hy + hr))
    local x0 = math.max(0, math.floor(hx - hr))
    local x1 = math.min(W - 1, math.ceil(hx + hr))
    for y = y0, y1 do
      for x = x0, x1 do
        local dx, dy = x - hx, y - hy
        if dx * dx + dy * dy <= hr * hr then m[y][x] = false end
      end
    end
  end
end

local function draw_conifer(px, m, rng, W, H, p, cx, base_y, x_top)
  local tiers = px.rngInt(rng, 4, 5)
  local total_h = p.height
  for tier = 1, tiers do
    local t0 = (tier - 1) / tiers
    local t1 = tier / tiers
    local y_bot = base_y - total_h * t0 * 0.96
    local y_top = base_y - total_h * t1
    local half_top = (W * 0.30) * (1 - t1 * 0.7)
    local half_bot = (W * 0.34) * (1 - t0 * 0.7)
    local cx_t = cx + (x_top - cx) * t1 + (rng() - 0.5) * 1.5
    local cx_b = cx + (x_top - cx) * t0 + (rng() - 0.5) * 1.5
    -- 本层主体（微拱）
    for y = math.floor(y_top), math.ceil(y_bot) do
      local tt = (y - y_top) / math.max(1, y_bot - y_top)
      local half = half_top + (half_bot - half_top) * tt
      local cxx = cx_t + (cx_b - cx_t) * tt
      local wob = (rng() - 0.5) * 1.2
      for x = math.floor(cxx - half + wob), math.ceil(cxx + half + wob) do
        px.set(m, x, y, true)
      end
    end
    -- 底缘下垂枝（锯齿三角形）
    local teeth = math.max(3, math.floor(half_bot * 0.9))
    for k = 0, teeth do
      local tx = cx_b - half_bot + (2 * half_bot) * (k / teeth)
      local depth = px.rngRange(rng, 1.5, 3.5)
      local wid = px.rngRange(rng, 0.7, 1.5)
      px.polygon(m, {
        {tx - wid, y_bot - 1}, {tx + wid, y_bot - 1}, {tx, y_bot + depth},
      })
    end
  end
end

local function generate(ctx)
  local px = ctx.px
  local W, H = ctx.size[1], ctx.size[2]
  local p = ctx.params
  local rng = ctx.rng

  -- 1) 树干与树枝（单独 mask，便于单独配色与纹理）
  local trunk = px.canvas(W, H)
  local cx, base_y, x_top, trunk_top = draw_trunk(px, trunk, rng, W, H, p)

  -- 2) 树冠 / 松柏层（单独 mask）
  local canopy = px.canvas(W, H)
  if p.kind == "broadleaf" then
    draw_canopy(px, canopy, rng, W, H, p, cx, trunk_top)
  elseif p.kind == "conifer" then
    draw_conifer(px, canopy, rng, W, H, p, cx, base_y, x_top)
  end

  -- 合并主 mask（枯树：枝杈已在 trunk 中）
  local m = px.canvas(W, H)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      m[y][x] = trunk[y][x] or canopy[y][x]
    end
  end
  px.despike(m)

  local img = px.newImage(W, H)
  local light = ctx.style.lighting

  -- 树干明暗 + 树皮刻线 + 苔藓
  local wood = px.rampOf(ctx.style, p.kind == "dead" and "wood_dead" or "bark")
  px.paintShaded(img, trunk, wood, {light = light, rng = rng, jitter = true})
  if p.kind ~= "dead" then
    local lines = px.rngInt(rng, 2, 4)
    for _ = 1, lines do
      local lx = cx + (rng() - 0.5) * 3
      px.carve(img, trunk, lx, base_y - 2, lx + (rng() - 0.5) * 2,
        trunk_top + rng() * 4, wood, {level = 1})
    end
  end

  -- 树冠明暗 + 叶簇纹理
  if p.kind == "broadleaf" then
    local leaf = px.rampOf(ctx.style, "foliage_dark")
    px.paintShaded(img, canopy, leaf, {light = light, rng = rng, jitter = true, jitterChance = 0.4})
    px.clusterJitter(img, canopy, leaf, rng, {chance = 0.35})
    -- 顶部叶簇块状高光（偏向左上）
    local cy_top = trunk_top
    px.speckle(img, canopy, leaf, rng, {
      count = 7, levels = {4, 5}, size = 2,
      filter = function(x, y)
        return y < cy_top + 2 and x < W / 2 + 6
      end,
    })
    -- 底部暗压（AO 带）
    for y = 0, H - 1 do
      for x = 0, W - 1 do
        if canopy[y][x] then
          local _, _, _, dB = px.edgeDistances(canopy, x, y)
          if dB <= 2 then
            local lvl = px.levelOf(leaf, img:getPixel(x, y)) or 2
            img:putPixel(x, y, px.rampColor(leaf, math.min(lvl, 2)))
          end
        end
      end
    end
  elseif p.kind == "conifer" then
    local leaf = px.rampOf(ctx.style, "foliage_dark")
    px.paintShaded(img, canopy, leaf, {light = light, rng = rng, jitter = true, jitterChance = 0.4})
    px.clusterJitter(img, canopy, leaf, rng, {chance = 0.3})
    -- 层间阴影：短线段（不横贯全宽，避免“蛋糕层”）
    for tier = 1, 5 do
      local y = base_y - p.height * (tier / 5.4)
      px.carve(img, canopy, cx - W / 3.5, y, cx + W / 4, y, leaf, {level = 1})
    end
    px.speckle(img, canopy, leaf, rng, {
      count = 8, levels = {4}, size = 2,
      filter = function(x, _) return x < cx end,
    })
  end

  -- 苔藓点缀（树干+树冠）
  if p.moss > 0.05 then
    local moss = px.rampOf(ctx.style, "moss")
    local count = math.floor(2 + p.moss * 8)
    px.speckle(img, trunk, moss, rng, {count = count, size = 1, levels = {2, 3}})
    if p.kind == "broadleaf" then
      px.speckle(img, canopy, moss, rng, {count = count, size = 1, levels = {2, 3}})
    end
  end

  -- 轮廓
  px.outline(img, m, ctx.style.outline.color, {
    policy = ctx.style.outline.policy, light = light, rng = rng,
  })
  return {img = img, mask = m}
end

return {
  name = "tree",
  category = "nature",
  size = {40, 48},
  params = {
    kind = {type = "choice", values = {"broadleaf", "dead", "conifer"}, default = "broadleaf"},
    height = {type = "int", min = 26, max = 42, default = 34},
    canopy = {type = "float", min = 0.25, max = 0.55, default = 0.4},
    asymmetry = {type = "float", min = 0, max = 1, default = 0.35},
    lean = {type = "float", min = -0.15, max = 0.15, default = 0.05},
    moss = {type = "float", min = 0, max = 1, default = 0.5},
  },
  generate = generate,
}
