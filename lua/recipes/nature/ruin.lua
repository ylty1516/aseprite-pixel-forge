-- ruin.lua — 遗迹残件：断柱 / 砖堆 / 拱残件（哥特教会遗迹）
local function rounded_rect(px, x0, y0, x1, y1)
  local b = px.canvas(48, 48)
  px.rect(b, x0, y0, x1, y1)
  if x1 - x0 >= 2 and y1 - y0 >= 2 then
    px.set(b, x0, y0, false); px.set(b, x1, y0, false)
    px.set(b, x0, y1, false); px.set(b, x1, y1, false)
  end
  return b
end

-- ---------------- 断柱 ----------------
local function gen_column(ctx, m)
  local px, rng = ctx.px, ctx.rng
  local p = ctx.params

  local base_y = 45
  local x_l = 16
  local x_r = 28
  local top_y = px.rngInt(rng, 6, 18) -- 越高断口越靠上

  local shaft = px.canvas(48, 48)
  -- 柱身（顶部碎裂：多点锯齿）
  local jag = {}
  local jag_n = px.rngInt(rng, 3, 5)
  for i = 0, jag_n do jag[i] = top_y + px.rngInt(rng, -4, 5) end
  for y = top_y - 4, base_y - 6 do
    for x = x_l, x_r do
      -- 顶部按锯齿裁掉
      local xi = math.floor((x - x_l) / (x_r - x_l) * jag_n + 0.5)
      local cut = jag[xi] or top_y
      if y >= cut then
        px.set(shaft, x, y, true)
      end
    end
  end

  -- 柱础（两级）
  px.rect(shaft, x_l - 4, base_y - 5, x_r + 4, base_y - 1)
  px.rect(shaft, x_l - 2, base_y - 7, x_r + 2, base_y - 5)
  px.set(shaft, x_l - 4, base_y - 5, false)
  px.set(shaft, x_r + 4, base_y - 5, false)

  -- 侵蚀缺口
  if p.decay > 0.05 then
    local chips = math.floor(p.decay * 6)
    for _ = 1, chips do
      local bx = px.rngInt(rng, x_l - 2, x_r + 2)
      local by = px.rngInt(rng, top_y, base_y - 2)
      local r = px.rngRange(rng, 1, 2.4)
      for y = math.floor(by - r), math.ceil(by + r) do
        for x = math.floor(bx - r), math.ceil(bx + r) do
          local dx, dy = x - bx, y - by
          if dx * dx + dy * dy <= r * r then shaft[y][x] = false end
        end
      end
    end
  end
  px.despike(shaft)

  local stone = px.rampOf(ctx.style, "stone")
  local img = ctx.img
  px.paintShaded(img, shaft, stone, {light = ctx.style.lighting, rng = rng, jitter = true, levelShift = -1})

  -- 凹槽（竖向刻线）
  local flutes = px.rngInt(rng, 3, 5)
  for i = 1, flutes do
    local fx = x_l + 2 + i * ((x_r - x_l - 3) / (flutes + 1)) + (rng() - 0.5)
    px.carve(img, shaft, fx, top_y + 2, fx, base_y - 8, stone, {level = 1})
  end
  -- 裂纹
  for _ = 1, px.rngInt(rng, 1, 2) do
    local x0 = px.rngInt(rng, x_l, x_r)
    px.carve(img, shaft, x0, top_y + px.rngInt(rng, 2, 8), x0 + px.rngInt(rng, -3, 3),
      top_y + px.rngInt(rng, 12, 26), stone, {level = 1})
  end

  -- 苔藓（底部重、断口轻）
  if p.moss > 0.05 then
    local moss = px.rampOf(ctx.style, "moss")
    px.speckle(img, shaft, moss, rng, {count = math.floor(3 + p.moss * 10),
      size = 1, levels = {2, 3}})
    local base_band = px.canvas(48, 48)
    px.rect(base_band, x_l - 4, base_y - 4, x_r + 4, base_y - 1)
    px.speckle(img, base_band, moss, rng, {count = math.floor(2 + p.moss * 6),
      size = 2, levels = {2, 3}})
  end

  for y = 0, 47 do
    for x = 0, 47 do
      if shaft[y][x] then m[y][x] = true end
    end
  end
end

-- ---------------- 砖堆 ----------------
local function gen_bricks(ctx, m)
  local px, rng = ctx.px, ctx.rng
  local p = ctx.params
  local img = ctx.img
  local ground = 45

  local brick = px.rampOf(ctx.style, "stone_warm")
  local rows = {
    {y0 = ground - 3, y1 = ground, count = px.rngInt(rng, 4, 6)},
    {y0 = ground - 7, y1 = ground - 4, count = px.rngInt(rng, 3, 4)},
    {y0 = ground - 10, y1 = ground - 8, count = px.rngInt(rng, 1, 3)},
  }
  local all = px.canvas(48, 48)
  for _, row in ipairs(rows) do
    local total_w = row.count * 8
    local x = math.floor((48 - total_w) / 2) + px.rngInt(rng, -2, 2)
    for _ = 1, row.count do
      local w = px.rngInt(rng, 5, 7)
      local b = rounded_rect(px, x, row.y0, x + w, row.y1)
      -- 破损：随机砍角
      if p.decay > 0.1 and rng() < p.decay then
        px.set(b, x + w, rng() < 0.5 and row.y0 or row.y1, false)
      end
      px.paintShaded(img, b, brick, {light = ctx.style.lighting, rng = rng, jitter = true, levelShift = -1})
      if rng() < 0.4 then
        px.carve(img, b, x + 1, row.y1 - 1, x + w - 1, row.y0 + 1, brick, {level = 1})
      end
      for y = 0, 47 do
        for xx = 0, 47 do
          if b[y][xx] then all[y][xx] = true end
        end
      end
      x = x + w + px.rngInt(rng, 2, 3)
    end
  end

  -- 散砖
  for _ = 1, px.rngInt(rng, 1, 2) do
    local x = px.rngInt(rng, 4, 40)
    local b = rounded_rect(px, x, ground - 2, x + 6, ground)
    px.paintShaded(img, b, brick, {light = ctx.style.lighting, rng = rng, jitter = true, levelShift = -1})
    for y = 0, 47 do
      for xx = 0, 47 do
        if b[y][xx] then all[y][xx] = true end
      end
    end
  end

  if p.moss > 0.05 then
    local moss = px.rampOf(ctx.style, "moss")
    px.speckle(img, all, moss, rng, {count = math.floor(3 + p.moss * 12),
      size = 1, levels = {2, 3, 4}})
  end

  for y = 0, 47 do
    for x = 0, 47 do
      if all[y][x] then m[y][x] = true end
    end
  end
end

-- ---------------- 拱残件 ----------------
local function gen_arch(ctx, m)
  local px, rng = ctx.px, ctx.rng
  local p = ctx.params
  local img = ctx.img

  local cx, cy = 24, 40
  local r_out = px.rngRange(rng, 15, 17)
  local r_in = r_out - px.rngRange(rng, 5, 7)
  local a0 = math.rad(px.rngInt(rng, 185, 205))       -- 左端
  local a1_base = math.rad(px.rngInt(rng, 315, 345))  -- 右端（断口）

  local arch = px.canvas(48, 48)
  for y = 0, 47 do
    for x = 0, 47 do
      local dx, dy = x - cx, y - cy
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist >= r_in and dist <= r_out then
        local a = math.atan(dy, dx)
        if a < 0 then a = a + math.pi * 2 end
        -- 断口沿半径抖动 → 锯齿碎裂感
        local a1 = a1_base + (dist - r_in) * 0.03 + (rng() - 0.5) * 0.12
        if a >= a0 and a <= a1 then
          px.set(arch, x, y, true)
        end
      end
    end
  end
  -- 底部切平（立在基线上）
  for x = 0, 47 do
    for y = 44, 47 do arch[y][x] = false end
  end
  if p.decay > 0.05 then
    px.perturb(arch, rng, 0.06 + p.decay * 0.12)
  end
  px.despike(arch)

  local stone = px.rampOf(ctx.style, "stone")
  px.paintShaded(img, arch, stone, {light = ctx.style.lighting, rng = rng, jitter = true, levelShift = -1})

  -- 楔形石缝（径向线）
  local seams = px.rngInt(rng, 3, 5)
  for i = 1, seams do
    local a = a0 + (a1_base - a0) * (i / (seams + 1))
    local x0 = cx + math.cos(a) * r_in
    local y0 = cy + math.sin(a) * r_in
    local x1 = cx + math.cos(a) * r_out
    local y1 = cy + math.sin(a) * r_out
    px.carve(img, arch, x0, y0, x1, y1, stone, {level = 1})
  end

  -- 基座碎石
  for _ = 1, px.rngInt(rng, 2, 3) do
    local rx = px.rngInt(rng, 8, 40)
    local rr = px.rngRange(rng, 1.5, 3)
    local rk = px.canvas(48, 48)
    px.polygon(rk, {
      {rx - rr, 45}, {rx + rr, 45}, {rx + rr * 0.6, 45 - rr * 1.3},
      {rx - rr * 0.5, 45 - rr},
    })
    px.paintShaded(img, rk, stone, {light = ctx.style.lighting, rng = rng, levelShift = -1})
    for y = 0, 47 do
      for x = 0, 47 do
        if rk[y][x] then arch[y][x] = true end
      end
    end
  end

  if p.moss > 0.05 then
    local moss = px.rampOf(ctx.style, "moss")
    px.speckle(img, arch, moss, rng, {count = math.floor(3 + p.moss * 12),
      size = 1, levels = {2, 3, 4}})
  end

  for y = 0, 47 do
    for x = 0, 47 do
      if arch[y][x] then m[y][x] = true end
    end
  end
end

local function generate(ctx)
  local px = ctx.px
  local m = px.canvas(48, 48)
  ctx.img = px.newImage(48, 48)

  local p = ctx.params
  if p.kind == "column" then
    gen_column(ctx, m)
  elseif p.kind == "bricks" then
    gen_bricks(ctx, m)
  else
    gen_arch(ctx, m)
  end

  px.outline(ctx.img, m, ctx.style.outline.color, {
    policy = ctx.style.outline.policy, light = ctx.style.lighting, rng = ctx.rng,
  })
  return {img = ctx.img, mask = m}
end

return {
  name = "ruin",
  category = "nature",
  size = {48, 48},
  params = {
    kind = {type = "choice", values = {"column", "bricks", "arch"}, default = "column"},
    decay = {type = "float", min = 0, max = 1, default = 0.35},
    moss = {type = "float", min = 0, max = 1, default = 0.5},
  },
  generate = generate,
}
