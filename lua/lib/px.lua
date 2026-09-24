-- px.lua — aseprite-pixel-forge 像素技法库
-- 约定：mask 是 {w=, h=} 且 m[y][x]=true/false 的二维表；img 是 Aseprite Image。
-- 所有随机均通过注入的 rng（xorshift32）以保确定性。

local px = {}

-- ============================================================ 随机

function px.rng(seed)
  local s = math.floor(seed or 1) % 4294967296
  if s <= 0 then s = 2463534242 end
  return function()
    s = (s ~ (s << 13)) & 0xFFFFFFFF
    s = s ~ (s >> 17)
    s = (s ~ (s << 5)) & 0xFFFFFFFF
    return s / 4294967296.0
  end
end

function px.rngInt(rng, min, max)
  return min + math.floor(rng() * (max - min + 1))
end

function px.rngRange(rng, a, b)
  return a + rng() * (b - a)
end

function px.chance(rng, p)
  return rng() < p
end

function px.pick(rng, arr)
  local i = math.max(1, math.min(#arr, math.ceil(rng() * #arr)))
  return arr[i]
end

-- ============================================================ Canvas / Mask

function px.canvas(w, h)
  local m = {w = w, h = h}
  for y = 0, h - 1 do
    local row = {}
    for x = 0, w - 1 do row[x] = false end
    m[y] = row
  end
  return m
end

function px.inside(m, x, y)
  return x >= 0 and y >= 0 and x < m.w and y < m.h
end

function px.get(m, x, y)
  x, y = math.floor(x), math.floor(y)
  if not px.inside(m, x, y) then return false end
  return m[y][x] and true or false
end

function px.set(m, x, y, v)
  x, y = math.floor(x), math.floor(y)
  if px.inside(m, x, y) then m[y][x] = v and true or false end
end

function px.maskCount(m)
  local n = 0
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if m[y][x] then n = n + 1 end
    end
  end
  return n
end

function px.rect(m, x0, y0, x1, y1)
  for y = math.floor(y0), math.ceil(y1) do
    for x = math.floor(x0), math.ceil(x1) do px.set(m, x, y, true) end
  end
end

function px.disk(m, cx, cy, rx, ry)
  ry = ry or rx
  for y = math.floor(cy - ry), math.ceil(cy + ry) do
    for x = math.floor(cx - rx), math.ceil(cx + rx) do
      local nx = (x - cx) / rx
      local ny = (y - cy) / ry
      if nx * nx + ny * ny <= 1.0 then px.set(m, x, y, true) end
    end
  end
end

function px.lineMask(m, x0, y0, x1, y1, thickness)
  x0, y0, x1, y1 = math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1)
  local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    if thickness and thickness > 1 then
      local r = (thickness - 1) / 2
      px.disk(m, x0, y0, math.max(0.5, r), math.max(0.5, r))
    else
      px.set(m, x0, y0, true)
    end
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
  end
end

function px.polygon(m, pts)
  local minY, maxY = math.huge, -math.huge
  for _, p in ipairs(pts) do
    minY = math.min(minY, p[2])
    maxY = math.max(maxY, p[2])
  end
  for y = math.floor(minY), math.ceil(maxY) do
    local xs = {}
    local n = #pts
    for i = 1, n do
      local a, b = pts[i], pts[i % n + 1]
      local ay, by = a[2], b[2]
      if (ay <= y and by > y) or (by <= y and ay > y) then
        local t = (y - ay) / (by - ay)
        table.insert(xs, a[1] + t * (b[1] - a[1]))
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = math.ceil(xs[i]), math.floor(xs[i + 1]) do px.set(m, x, y, true) end
    end
  end
end

-- 不规则圆（树冠/岩石/灌木用）
function px.blob(m, rng, cx, cy, r, opts)
  opts = opts or {}
  local irregularity = opts.irregularity or 0.35
  local points = opts.points or 12
  local radii = {}
  for i = 1, points do radii[i] = r * (1 - irregularity * rng()) end
  for _ = 1, (opts.smooth or 1) do
    local next_radii = {}
    for i = 1, points do
      local prev = radii[i == 1 and points or i - 1]
      local nxt = radii[i == points and 1 or i + 1]
      next_radii[i] = (prev + radii[i] * 2 + nxt) / 4
    end
    radii = next_radii
  end
  local pts = {}
  for i = 1, points do
    local a = (i - 1) / points * math.pi * 2
    table.insert(pts, {cx + math.cos(a) * radii[i], cy + math.sin(a) * radii[i]})
  end
  px.polygon(m, pts)
end

-- 左半镜像到右半（以中线）
function px.mirrorX(m)
  local half = math.floor(m.w / 2)
  for y = 0, m.h - 1 do
    for x = 0, half - 1 do
      if m[y][x] then m[y][m.w - 1 - x] = true end
    end
  end
end

function px.boundary(m, x, y)
  for oy = -1, 1 do
    for ox = -1, 1 do
      if not (ox == 0 and oy == 0) and not px.get(m, x + ox, y + oy) then
        return true
      end
    end
  end
  return false
end

-- 边界扰动：让形状脱离几何感；随后清理孤立点/填补凹洞
function px.perturb(m, rng, amount)
  amount = amount or 0.2
  local removes, adds = {}, {}
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if m[y][x] then
        if px.boundary(m, x, y) and rng() < amount then
          table.insert(removes, {x, y})
        end
      else
        local touch = false
        for oy = -1, 1 do
          for ox = -1, 1 do
            if px.get(m, x + ox, y + oy) then touch = true end
          end
        end
        if touch and rng() < amount * 0.7 then table.insert(adds, {x, y}) end
      end
    end
  end
  for _, p in ipairs(removes) do m[p[2]][p[1]] = false end
  for _, p in ipairs(adds) do m[p[2]][p[1]] = true end
  px.despike(m)
end

function px.despike(m)
  local remove, add = {}, {}
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      local n = 0
      for oy = -1, 1 do
        for ox = -1, 1 do
          if not (ox == 0 and oy == 0) and px.get(m, x + ox, y + oy) then n = n + 1 end
        end
      end
      if m[y][x] and n < 2 then table.insert(remove, {x, y})
      elseif not m[y][x] and n >= 6 then table.insert(add, {x, y}) end
    end
  end
  for _, p in ipairs(remove) do m[p[2]][p[1]] = false end
  for _, p in ipairs(add) do m[p[2]][p[1]] = true end
end

-- ============================================================ 颜色

function px.rgba(r, g, b, a)
  return app.pixelColor.rgba(r, g, b, a or 255)
end

function px.rgbaParts(c)
  return app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c),
         app.pixelColor.rgbaB(c), app.pixelColor.rgbaA(c)
end

function px.rampOf(style, name)
  local ramp = style and style.ramps and style.ramps[name]
  if not ramp then
    error("style 中不存在色阶: " .. tostring(name))
  end
  return ramp
end

function px.rampColor(ramp, level)
  level = math.floor(level + 0.5)
  level = math.max(1, math.min(#ramp, level))
  return ramp[level]
end

function px.levelOf(ramp, color)
  local key = px.colorInt(color)
  for i, c in ipairs(ramp) do
    if px.colorInt(c) == key then return i end
  end
  return nil
end

-- ============================================================ 明暗 / 轮廓 / 纹理

function px.edgeDistances(m, x, y)
  local dL, dR, dT, dB = 0, 0, 0, 0
  local X = x
  while X >= 0 and m[y][X] do dL = dL + 1; X = X - 1 end
  X = x
  while X < m.w and m[y][X] do dR = dR + 1; X = X + 1 end
  local Y = y
  while Y >= 0 and m[Y][x] do dT = dT + 1; Y = Y - 1 end
  Y = y
  while Y < m.h and m[Y][x] do dB = dB + 1; Y = Y + 1 end
  return dL, dR, dT, dB
end

-- 光照方向明暗：光侧亮、影侧暗 + 底部/右侧 AO 压暗 + 2x2 簇抖动
function px.paintShaded(img, m, ramp, opts)
  opts = opts or {}
  local light = opts.light or {dx = -1, dy = -1}
  local rng = opts.rng or px.rng(1)
  local ao = opts.ao or 1.0
  local n = #ramp
  local items = {}
  local minI, maxI = math.huge, -math.huge
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if m[y][x] then
        local dL, dR, dT, dB = px.edgeDistances(m, x, y)
        local litX = (dL - dR) / math.max(1, dL + dR)
        local litY = (dT - dB) / math.max(1, dT + dB)
        -- litX/litY 靠近小侧为负；光向点乘得到“面向光”的正分值
        local I = light.dx * litX + light.dy * litY
        local lx = light.dx == 0 and 0 or (light.dx < 0 and 1 or -1)
        local ly = light.dy == 0 and 0 or (light.dy < 0 and 1 or -1)
        -- AO/边缘调制相对光照方向（光侧抬、影侧压）
        if ly > 0 then
          if dB <= 1 then I = I - 0.55 * ao end
          if dT <= 1 and dB > 1 then I = I + 0.4 * ao end
        else
          if dT <= 1 then I = I - 0.55 * ao end
          if dB <= 1 and dT > 1 then I = I + 0.4 * ao end
        end
        if lx > 0 then
          if dR <= 1 then I = I - 0.25 * ao end
          if dL <= 1 and dR > 1 then I = I + 0.2 * ao end
        else
          if dL <= 1 then I = I - 0.25 * ao end
          if dR <= 1 and dL > 1 then I = I + 0.2 * ao end
        end
        if opts.topBias and y < m.h * 0.35 then I = I + opts.topBias end
        if opts.bottomBias and y > m.h * 0.65 then I = I - opts.bottomBias end
        table.insert(items, {x = x, y = y, I = I})
        if I < minI then minI = I end
        if I > maxI then maxI = I end
      end
    end
  end
  if #items == 0 then return end
  local span = maxI - minI
  if span < 0.001 then span = 0.001 end
  -- 2x2 块采样抖动（簇状纪律）
  local jitter = {}
  if opts.jitter then
    local bx0 = math.huge
    for _, it in ipairs(items) do bx0 = math.min(bx0, it.x) end
    for _, it in ipairs(items) do
      local key = math.floor(it.x / 2) * 10000 + math.floor(it.y / 2)
      if jitter[key] == nil then
        jitter[key] = (rng() < (opts.jitterChance or 0.3)) and
          ((rng() < 0.5) and -1 or 1) or 0
      end
      it.j = jitter[key]
    end
  end
  for _, it in ipairs(items) do
    local t = (it.I - minI) / span
    local level = 1 + math.floor(t * (n - 1) + 0.5)
    level = level + (it.j or 0) + (opts.levelShift or 0)
    img:putPixel(it.x, it.y, px.rampColor(ramp, level))
  end
end

-- 单色平涂
function px.flatten(img, m, ramp, level)
  local c = px.rampColor(ramp, level)
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if m[y][x] then img:putPixel(x, y, c) end
    end
  end
end

-- 只对指定子区域平涂
function px.flattenSub(img, m, sub, ramp, level)
  local c = px.rampColor(ramp, level)
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if m[y][x] and sub[y][x] then img:putPixel(x, y, c) end
    end
  end
end

-- 轮廓：selective 时影侧重、光侧断线；绘制在形状外侧（扩张）
function px.outline(img, m, color, opts)
  opts = opts or {}
  local policy = opts.policy or "full"
  if policy == "none" then return 0 end
  local light = opts.light or {dx = -1, dy = -1}
  local rng = opts.rng or px.rng(1)
  local breaks = opts.breaks or 0.45
  local count = 0
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if not m[y][x] then
        local shadowAny, any = false, false
        for oy = -1, 1 do
          for ox = -1, 1 do
            if not (ox == 0 and oy == 0) then
              local nx, ny = x + ox, y + oy
              if px.get(m, nx, ny) then
                any = true
                local dxo, dyo = x - nx, y - ny
                if (light.dx * dxo + light.dy * dyo) < 0 then shadowAny = true end
              end
            end
          end
        end
        if any and (policy == "full" or shadowAny or rng() < breaks) then
          img:putPixel(x, y, color)
          count = count + 1
        end
      end
    end
  end
  return count
end

local BAYER4 = {
  {0, 8, 2, 10},
  {12, 4, 14, 6},
  {3, 11, 1, 9},
  {15, 7, 13, 5},
}

-- Bayer 4×4 阈值（0..1）供外部抖动使用（坐标自动取整，浮点坐标安全）
function px.bayer(x, y)
  local xi = math.floor(x) % 4 + 1
  local yi = math.floor(y) % 4 + 1
  return BAYER4[yi][xi] / 16.0
end

-- 双色 Bayer 抖动填充（密度 0→全 A，1→全 B）
function px.ditherFill(img, m, ramp, levelA, levelB, opts)
  opts = opts or {}
  local density = opts.density or 0.5
  local ca = px.rampColor(ramp, levelA)
  local cb = px.rampColor(ramp, levelB)
  local threshold = density * 16
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if m[y][x] then
        local b = BAYER4[(y % 4) + 1][(x % 4) + 1]
        img:putPixel(x, y, (b < threshold) and cb or ca)
      end
    end
  end
end

-- 2x2 块级色阶抖动（簇状、反几何感；色值必须 ∈ ramp）
function px.clusterJitter(img, m, ramp, rng, opts)
  opts = opts or {}
  local chance = opts.chance or 0.3
  local step = opts.step or 1
  for by = 0, math.ceil(m.h / 2) - 1 do
    for bx = 0, math.ceil(m.w / 2) - 1 do
      if rng() < chance then
        local delta = (rng() < 0.5) and -step or step
        for oy = 0, 1 do
          for ox = 0, 1 do
            local x, y = bx * 2 + ox, by * 2 + oy
            if px.inside(m, x, y) and m[y][x] then
              local level = px.levelOf(ramp, img:getPixel(x, y))
              if level then
                img:putPixel(x, y, px.rampColor(ramp, level + delta))
              end
            end
          end
        end
      end
    end
  end
end

-- 点缀（苔藓/地衣/杂色），小簇绘制，等级取 opts.levels
-- opts.filter(x, y) 可限定区域（如仅顶部）；opts.bias_top 简化玩法：偏向 y 较小的区域
function px.speckle(img, m, ramp, rng, opts)
  opts = opts or {}
  local count = opts.count or 8
  local size = opts.size or 1
  local levels = opts.levels or {2, 3}
  local filter = opts.filter
  local pixels = {}
  for y = 0, m.h - 1 do
    for x = 0, m.w - 1 do
      if m[y][x] then table.insert(pixels, {x, y}) end
    end
  end
  if #pixels == 0 then return end
  local placed, tries = 0, 0
  while placed < count and tries < count * 25 do
    tries = tries + 1
    local p = pixels[px.rngInt(rng, 1, #pixels)]
    local okp = (not filter) or filter(p[1], p[2])
    if okp then
      local level = px.pick(rng, levels)
      local c = px.rampColor(ramp, level)
      local any = false
      for oy = 0, size - 1 do
        for ox = 0, size - 1 do
          local x, y = p[1] + ox, p[2] + oy
          if px.inside(m, x, y) and m[y][x] then
            img:putPixel(x, y, c)
            any = true
          end
        end
      end
      if any then placed = placed + 1 end
    end
  end
end

-- 刻线（树皮/裂纹），仅落在 mask 内
function px.carve(img, m, x0, y0, x1, y1, ramp, opts)
  opts = opts or {}
  local level = opts.level or 1
  local c = px.rampColor(ramp, level)
  x0, y0, x1, y1 = math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1)
  local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    if px.inside(m, x0, y0) and m[y0][x0] then img:putPixel(x0, y0, c) end
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x0 = x0 + sx end
    if e2 < dx then err = err + dx; y0 = y0 + sy end
  end
end

-- 行级弯曲摆动（草地/花草/狭长物件）：根部固定，越高偏移越大；
-- 按连通段平移并保持行宽度（空出的像素用该段内缘延伸），消除断线。
-- opts: amp 最大偏移像素、pivot 根部行、phase 相位（弧度）、falloff 幂曲线
function px.shear(img, m, opts)
  opts = opts or {}
  local amp = opts.amp or 2.0
  local pivot = opts.pivot or (m.h - 1)
  local phase = opts.phase or 0.0
  local falloff = opts.falloff or 1.6
  local span = math.max(1, pivot)
  local out = px.newImage(m.w, m.h)
  local om = px.canvas(m.w, m.h)
  for y = 0, m.h - 1 do
    local t = math.max(0, (pivot - y) / span)
    local dx = math.floor(amp * (t ^ falloff) * math.sin(phase) + 0.5)
    -- 本行连通段
    local runs = {}
    local x = 0
    while x < m.w do
      if m[y][x] then
        local a = x
        while x + 1 < m.w and m[y][x + 1] do x = x + 1 end
        table.insert(runs, {a, x})
      end
      x = x + 1
    end
    for _, r in ipairs(runs) do
      local a, b = r[1], r[2]
      local na, nb = a + dx, b + dx
      if nb >= 0 and na < m.w then
        na = math.max(0, na)
        nb = math.min(m.w - 1, nb)
        for tx = na, nb do
          local src = math.min(b, math.max(a, tx - dx))
          out:putPixel(tx, y, img:getPixel(src, y))
          px.set(om, tx, y, true)
        end
      end
    end
  end
  return out, om
end

-- ============================================================ 场景氛围（调色/光照/大气）

-- 颜色归一：table {r,g,b,a} → 整数；整数原样返回
function px.colorInt(c)
  if type(c) == "table" then
    return app.pixelColor.rgba(c.r, c.g, c.b, c.a or 255)
  end
  return c
end

-- 色板反查表：color(整数) → {ramp=名, level=序号}
function px.paletteIndex(style)
  local index = {}
  for name, ramp in pairs(style.ramps) do
    for i, c in ipairs(ramp) do
      index[px.colorInt(c)] = { ramp = name, level = i }
    end
  end
  return index
end

-- 直拷带透明像素的小图（素材拼贴）
function px.blit(img, src, x0, y0)
  for y = 0, src.height - 1 do
    for x = 0, src.width - 1 do
      local c = src:getPixel(x, y)
      if app.pixelColor.rgbaA(c) > 0 then
        img:putPixel(x0 + x, y0 + y, c)
      end
    end
  end
end

-- 光照：同 ramp 内提升/压低 level（光池/压暗）；sources 距离衰减
-- source: {x, y, r, strength, falloff, squash}；squash>1 时纵向压扁（地面透视椭圆光池）
function px.relight(img, index, ramps, sources, opts)
  opts = opts or {}
  local global = opts.shift or 0
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local c = img:getPixel(x, y)
      if app.pixelColor.rgbaA(c) > 0 then
        local info = index[c]
        if info then
          local boost = global
          for _, s in ipairs(sources) do
            local dx = x - s.x
            local dy = (y - s.y) * (s.squash or 1.0)
            local d = math.sqrt(dx * dx + dy * dy)
            if d < s.r then
              local f = (1 - d / s.r) ^ (s.falloff or 2.0)
              boost = boost + (s.strength or 1.0) * f
            end
          end
          local lv = info.level + math.floor(boost + (boost >= 0 and 0.5 or -0.5))
          if lv ~= info.level then
            img:putPixel(x, y, px.rampColor(ramps[info.ramp], lv))
          end
        end
      end
    end
  end
end

-- 调色：ramp→ramp 有序抖动交叉（palette 安全），支持 filter 与 level 平移
-- spec: { ["rampName"] = {target=, blend=0..1, shift=, filter=function(x,y)} }
function px.grade(img, index, ramps, spec, opts)
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local c = img:getPixel(x, y)
      if app.pixelColor.rgbaA(c) > 0 then
        local info = index[c]
        if info then
          local rule = spec[info.ramp]
          if rule and (not rule.filter or rule.filter(x, y)) then
            local target = ramps[rule.target]
            if target then
              local b = rule.blend or 1.0
              local take = b >= 1.0
              if not take and b > 0 then
                take = (BAYER4[(y % 4) + 1][(x % 4) + 1] / 16.0) < b
              end
              if take then
                img:putPixel(x, y, px.rampColor(target, info.level + (rule.shift or 0)))
              end
            end
          end
        end
      end
    end
  end
end

-- 光源暖色池：中心近乎实心换色，向外覆盖率递减（有序抖动过渡）
-- opts: x, y, r, squash(纵向压扁), ramps={ramp名列表}, target, core(中心覆盖率), edge(边缘覆盖率)
function px.warmPool(img, index, ramps, opts)
  local r = opts.r or 40
  local squash = opts.squash or 1.0
  local target = ramps[opts.target or "stone_warm"]
  local core = opts.core or 0.78
  local edge = opts.edge or 0.12
  local names = {}
  local any = false
  for _, n in ipairs(opts.ramps or {}) do
    names[n] = true
    any = true
  end
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local dx = x - opts.x
      local dy = (y - opts.y) * squash
      local d = math.sqrt(dx * dx + dy * dy)
      if d < r then
        local t = 1 - d / r          -- 1 中心 → 0 边缘
        local p = edge + (core - edge) * (t ^ 0.7)
        local c = img:getPixel(x, y)
        local info = index[c]
        if info and (not any or names[info.ramp]) then
          if (BAYER4[(y % 4) + 1][(x % 4) + 1] / 16.0) < p then
            img:putPixel(x, y, px.rampColor(target, info.level))
          end
        end
      end
    end
  end
end

-- 平滑丘陵（正弦叠加，死亡搁浅式起伏）；fill 向下，可选顶部 2px 亮边
function px.hills(img, ramps, rng, opts)
  local ramp = ramps[opts.ramp or "moss"]
  local level = opts.level or 3
  local base = opts.y or img.height * 0.7
  local amp = opts.amplitude or 10
  local w = img.width
  -- 三层正弦叠加，相位随机（同 seed 稳定）
  local p1, p2, p3 = rng() * 6.28, rng() * 6.28, rng() * 6.28
  local f1 = px.rngRange(rng, 0.010, 0.020)
  local f2 = px.rngRange(rng, 0.025, 0.045)
  local f3 = px.rngRange(rng, 0.06, 0.10)
  local color = px.rampColor(ramp, level)
  local color_hi = px.rampColor(ramp, level + 1)
  for x = 0, w - 1 do
    local hh = math.sin(x * f1 + p1) * 0.55
      + math.sin(x * f2 + p2) * 0.3
      + math.sin(x * f3 + p3) * 0.15
    local top = math.floor(base - hh * amp)
    for y = top, img.height - 1 do
      if (not opts.only_empty) or app.pixelColor.rgbaA(img:getPixel(x, y)) == 0 then
        img:putPixel(x, y, (y <= top + 1 and hh > 0.15) and color_hi or color)
      end
    end
  end
end

-- ============================================================ 巨构构件库（史诗尺度）
-- 全部构件：左侧受光（左上光），颜色只走 ramp level（渲染后由雾/调色统一氛围）

-- 塔楼：竖肋 + 两级退台 + 窗带 + 天线组
local function mega_tower(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c_body = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local span = math.max(1, base - top)
  local w2 = math.max(4, math.floor(w * 0.72))
  local w3 = math.max(3, math.floor(w * 0.45))
  local y1 = top + math.floor(span * 0.15)
  local y2 = top + math.floor(span * 0.55)
  local win_seed = math.floor(rng() * 7)
  for yy = math.max(0, top), base - 1 do
    local rw, rx
    if yy < y1 then rw, rx = w3, x + math.floor((w - w3) / 2)
    elseif yy < y2 then rw, rx = w2, x + math.floor((w - w2) / 2)
    else rw, rx = w, x end
    local step_edge = (yy == y1 or yy == y2)
    for xx = rx, rx + rw - 1 do
      if xx >= 0 and xx < img.width then
        local rel = xx - rx
        local c
        if step_edge then c = c_hi
        elseif rel == 0 then c = c_hi
        elseif rel == rw - 1 then c = c_lo
        elseif ((yy - top) % 5 <= 1) and rel > 1 and rel < rw - 2
          and ((rel * 2 + yy * 3 + win_seed) % 3 ~= 0) then
          c = c_lo
        elseif (rel % 4 == 2) then c = c_lo
        else c = c_body end
        img:putPixel(xx, yy, c)
      end
    end
  end
  -- 天线组
  local masts = px.rngInt(rng, 1, 3)
  for m = 1, masts do
    local mx = (masts == 1) and (x + math.floor(w / 2))
      or (x + math.floor(w * (0.22 + 0.56 * (m - 1) / (masts - 1))))
    local mh = px.rngInt(rng, 8, 14 + m * 7)
    for i = 1, mh do
      if mx >= 0 and mx < img.width and top - i >= 0 then
        img:putPixel(mx, top - i, (i == mh) and c_hi or c_body)
      end
    end
    if mh > 9 then
      local by = top - math.floor(mh * 0.6)
      for d = 1, 3 do
        if mx + d < img.width and by >= 0 then img:putPixel(mx + d, by, c_lo) end
      end
    end
  end
end

-- 骨架塔（绗架）：锥形 + 横档 + X 斜撑（巨构标志物）
local function mega_frame(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local span = math.max(1, base - top)
  local top_w = math.max(3, math.floor(w * 0.2))
  local cell = px.rngInt(rng, 10, 16)
  for yy = math.max(0, top), base - 1 do
    local t = (yy - top) / span
    local rw = math.floor(top_w + (w - top_w) * t)
    local rx = x + math.floor((w - rw) / 2)
    local v = (yy - top) % cell
    for xx = rx, rx + rw - 1 do
      if xx >= 0 and xx < img.width then
        local rel = xx - rx
        local c2 = nil
        local edge = (rel == 0 or rel == rw - 1)
        local girder = (v < 2)
        if edge then c2 = (rel == 0) and c_hi or c_lo
        elseif girder then c2 = c
        else
          local u = rel / math.max(1, rw - 1)
          local d1 = math.abs(v / cell - u)
          local d2 = math.abs(v / cell - (1 - u))
          if d1 < 0.13 or d2 < 0.13 then c2 = c_lo end
        end
        if c2 then img:putPixel(xx, yy, c2) end
      end
    end
  end
  -- 顶部平台 + 小吊臂
  local ty = top - 1
  local cx = x + math.floor(w / 2)
  if ty >= 0 then
    for xx = cx - 3, cx + 3 do
      if xx >= 0 and xx < img.width then img:putPixel(xx, ty, c_hi) end
    end
  end
end

-- 巨筒（冷却塔形）：腰身内收 + 竖棱 + 顶口亮边
local function mega_tank(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local span = math.max(1, base - top)
  for yy = math.max(0, top), base - 1 do
    local u = (yy - top) / span          -- 0 顶 → 1 底
    local hw = w / 2 * (1 - 0.4 * math.sin(math.pi * (1 - u) * 0.9))
    local rx = x + math.floor(w / 2 - hw)
    local rw = math.max(2, math.floor(hw * 2))
    for xx = rx, rx + rw - 1 do
      if xx >= 0 and xx < img.width then
        local rel = xx - rx
        local c2
        if yy == top then c2 = c_hi
        elseif rel == 0 then c2 = c_hi
        elseif rel == rw - 1 then c2 = c_lo
        elseif rel % 3 == 0 then c2 = c_lo
        else c2 = c end
        img:putPixel(xx, yy, c2)
      end
    end
  end
end

-- 阶梯巨城（金字塔式退台）
local function mega_arcology(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local tiers = px.rngInt(rng, 3, 5)
  local span = math.max(1, base - top)
  for ti = 0, tiers - 1 do
    local y0 = top + math.floor(span * ti / tiers)
    local y1 = top + math.floor(span * (ti + 1) / tiers)
    local rw = math.max(4, math.floor(w * (1 - 0.18 * ti)))
    local rx = x + math.floor((w - rw) / 2)
    for yy = math.max(0, y0), math.min(y1, base - 1) do
      for xx = rx, rx + rw - 1 do
        if xx >= 0 and xx < img.width then
          local rel = xx - rx
          local c2
          if rel == 0 then c2 = c_hi
          elseif rel == rw - 1 then c2 = c_lo
          elseif ((yy - y0) % 5 <= 1) and rel > 1 and rel < rw - 2 and rel % 2 == 0 then
            c2 = c_lo
          else c2 = c end
          img:putPixel(xx, yy, c2)
        end
      end
    end
    for xx = rx, rx + rw - 1 do
      if xx >= 0 and xx < img.width and y0 >= 0 then img:putPixel(xx, y0, c_hi) end
    end
  end
end

-- 龙门巨构：双腿 + 顶梁 + 吊索（港口/造船坞尺度）
local function mega_gantry(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local leg_w = math.max(2, math.floor(w * 0.16))
  for yy = math.max(0, top), base - 1 do
    for _, lx in ipairs({ x, x + w - leg_w }) do
      for xx = lx, lx + leg_w - 1 do
        if xx >= 0 and xx < img.width then
          img:putPixel(xx, yy, (xx == lx) and c_hi or c_lo)
        end
      end
    end
  end
  -- 顶梁
  if top >= 0 then
    for xx = x, x + w - 1 do
      if xx >= 0 and xx < img.width then img:putPixel(xx, top, c_hi) end
    end
  end
  -- 腿间横撑（3 道）
  for k = 1, 3 do
    local by = top + math.floor((base - top) * k / 4)
    for xx = x + leg_w, x + w - leg_w - 1 do
      if xx >= 0 and xx < img.width and by >= 0 and by < img.height then
        img:putPixel(xx, by, c)
      end
    end
  end
  -- 吊索 + 吊块
  local hx = x + math.floor(w * 0.55)
  local hl = px.rngInt(rng, math.floor((base - top) * 0.3), math.floor((base - top) * 0.6))
  for i = 3, hl do
    local yy = top + i
    if hx < img.width and yy >= 0 and yy < img.height then img:putPixel(hx, yy, c_lo) end
  end
  local by2 = math.min(img.height - 1, top + hl + 1)
  if hx < img.width and by2 >= 0 then img:putPixel(hx, by2, c_hi) end
end

-- 抛物面天线：C 形弧 + 馈源杆（open_angle = 开口方向弧度）
local function mega_dish(img, ramps, rng, cx, cy, r, ramp, level, open_angle, with_strut)
  local c = px.rampColor(ramp, level)
  local c_hi = px.rampColor(ramp, level + 1)
  open_angle = open_angle or -0.9
  local steps = math.max(28, math.floor(r * 9))
  for i = 0, steps do
    local a = i / steps * math.pi * 2
    local rel = math.atan(math.sin(a - open_angle), math.cos(a - open_angle))
    if math.abs(rel) > 0.6 then
      local px_ = math.floor(cx + math.cos(a) * r)
      local py_ = math.floor(cy + math.sin(a) * r * 0.85)
      if px_ >= 0 and px_ < img.width and py_ >= 0 and py_ < img.height then
        img:putPixel(px_, py_, (math.cos(a - open_angle) < -0.3) and c_hi or c)
      end
    end
  end
  local fdx, fdy = math.cos(open_angle), math.sin(open_angle) * 0.85
  for d = 2, math.floor(r * 0.9) do
    local px_ = math.floor(cx + fdx * d)
    local py_ = math.floor(cy + fdy * d)
    if px_ >= 0 and px_ < img.width and py_ >= 0 and py_ < img.height then
      img:putPixel(px_, py_, c)
    end
  end
  local fx = math.floor(cx + fdx * r * 0.95)
  local fy = math.floor(cy + fdy * r * 0.95)
  if fx >= 0 and fx < img.width and fy >= 0 and fy < img.height then
    img:putPixel(fx, fy, c_hi)
  end
  if with_strut then
    for d = 1, math.max(2, math.floor(r * 0.55)) do
      local py_ = math.floor(cy + r * 0.85) + d
      if py_ < img.height and cx >= 0 and cx < img.width then
        img:putPixel(math.floor(cx), py_, c)
      end
    end
  end
end

-- 粗野主义综合体（配電中心/掩体）：层叠板带 + 结构柱 + 大门洞 + 屋顶设备与天线碟
local function mega_block(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local band = px.rngInt(rng, 9, 13)
  local col_w = px.rngInt(rng, 16, 24)
  for yy = math.max(0, top), base - 1 do
    for xx = x, x + w - 1 do
      if xx >= 0 and xx < img.width then
        local rel = xx - x
        local c2
        if yy == top then c2 = c_hi
        elseif rel == 0 then c2 = c_hi
        elseif rel == w - 1 then c2 = c_lo
        elseif ((yy - top) % band < 2) then c2 = c_lo
        elseif (rel % col_w == 0) then c2 = c_lo
        else c2 = c end
        img:putPixel(xx, yy, c2)
      end
    end
  end
  -- 层叠楼板挑檐（两道：亮线 + 下行阴影）
  local span2 = base - top
  for _, frac in ipairs({ 0.36, 0.66 }) do
    local ly = top + math.floor(span2 * frac)
    for xx = x - 1, x + w do
      if xx >= 0 and xx < img.width and ly >= 0 then
        img:putPixel(xx, ly, c_hi)
        if ly + 1 < img.height then img:putPixel(xx, ly + 1, c_lo) end
      end
    end
  end
  -- 中央大门洞 + 侧窗
  local gw = math.max(7, math.floor(w * 0.15))
  local gh = math.max(7, math.floor((base - top) * 0.32))
  local gx = x + math.floor((w - gw) / 2)
  for yy = math.max(0, base - gh), base - 1 do
    for xx = gx, gx + gw - 1 do
      if xx >= 0 and xx < img.width and yy >= 0 then
        img:putPixel(xx, yy, px.rampColor(g.ramp, 1))
      end
    end
  end
  for k = 1, 3 do
    local wx = x + 4 + k * 7
    for yy = math.max(0, base - 6), base - 4 do
      if wx >= 0 and wx < img.width and yy >= 0 then
        img:putPixel(wx, yy, px.rampColor(g.ramp, 1))
      end
    end
  end
  -- 屋顶设备：AC 箱体 + 天线杆
  for _ = 1, px.rngInt(rng, 2, 4) do
    local bx = x + px.rngInt(rng, 2, math.max(3, w - 9))
    local bw = px.rngInt(rng, 3, 7)
    local bh = px.rngInt(rng, 2, 4)
    for yy = top - bh, top - 1 do
      for xx = bx, bx + bw - 1 do
        if xx >= 0 and xx < img.width and yy >= 0 then img:putPixel(xx, yy, c) end
      end
    end
    if rng() < 0.5 then
      local mh = px.rngInt(rng, 8, 22)
      for i = 1, mh do
        local yy = top - bh - i
        if yy >= 0 and bx + 1 >= 0 and bx + 1 < img.width then
          img:putPixel(bx + 1, yy, (i == mh) and c_hi or c)
        end
      end
    end
  end
  -- 屋顶抛物面天线（随建筑宽度放大；宽体 DC 可两组）
  if rng() < 0.8 then
    local dr = math.max(6, math.min(14, math.floor(w * 0.09)))
    local dishes = (w >= 80 and rng() < 0.5) and 2 or 1
    for dd = 1, dishes do
      local frac = (dd == 1) and px.rngRange(rng, 0.2, 0.45) or px.rngRange(rng, 0.62, 0.8)
      mega_dish(img, ramps, rng, x + math.floor(w * frac),
        top - math.floor(dr * 0.75), dr, g.ramp, math.min(5, g.level + 1),
        px.rngRange(rng, -1.4, -0.4), false)
    end
  end
end

-- 锯齿屋面厂房（长条低矮 + 排气塔）
local function mega_hall(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local period = px.rngInt(rng, 8, 11)
  local tooth = 4
  local wall_top = math.max(0, top + tooth)
  for yy = wall_top, base - 1 do
    for xx = x, x + w - 1 do
      if xx >= 0 and xx < img.width then
        local rel = xx - x
        local c2
        if rel == 0 then c2 = c_hi
        elseif rel == w - 1 then c2 = c_lo
        elseif ((yy - wall_top) % 6 == 0) then c2 = c_lo
        else c2 = c end
        img:putPixel(xx, yy, c2)
      end
    end
  end
  -- 锯齿轮
  for k = 0, math.floor(w / period) do
    local bx = x + k * period
    for u = 0, period - 1 do
      local h = math.floor(tooth * u / period)
      local xx = bx + u
      if xx >= 0 and xx < img.width then
        for yy = wall_top - h, wall_top - 1 do
          if yy >= 0 then img:putPixel(xx, yy, (u == period - 1) and c_lo or c) end
        end
      end
    end
  end
  -- 滚门
  for _ = 1, px.rngInt(rng, 2, 3) do
    local dw = px.rngInt(rng, 6, 10)
    local dx = x + px.rngInt(rng, 2, math.max(3, w - dw - 2))
    for yy = math.max(0, base - 7), base - 1 do
      for xx = dx, dx + dw - 1 do
        if xx >= 0 and xx < img.width and yy >= 0 then
          img:putPixel(xx, yy, px.rampColor(g.ramp, 1))
        end
      end
    end
  end
  -- 排气塔
  for _ = 1, px.rngInt(rng, 1, 3) do
    local sx = x + px.rngInt(rng, 6, math.max(7, w - 6))
    local sh = px.rngInt(rng, 8, 18)
    for i = 1, sh do
      local yy = wall_top - tooth - i
      if yy >= 0 then
        if sx >= 0 and sx < img.width then img:putPixel(sx, yy, c_hi) end
        if sx + 1 >= 0 and sx + 1 < img.width then img:putPixel(sx + 1, yy, c_lo) end
      end
    end
  end
end

-- 绗架通讯塔（细长收锥 + 环箍 + 顶针）
local function mega_mast(img, ramps, rng, g)
  local x, w, top, base = g.x, g.w, g.top, g.base
  local c = px.rampColor(g.ramp, g.level)
  local c_hi = px.rampColor(g.ramp, g.level + 1)
  local c_lo = px.rampColor(g.ramp, math.max(1, g.level - 1))
  local span = math.max(1, base - top)
  local top_w = 2
  local cell = px.rngInt(rng, 9, 13)
  for yy = math.max(0, top), base - 1 do
    local t = (yy - top) / span
    local rw = math.max(2, math.floor(top_w + (w - top_w) * t))
    local rx = x + math.floor((w - rw) / 2)
    local v = (yy - top) % cell
    for xx = rx, rx + rw - 1 do
      if xx >= 0 and xx < img.width then
        local rel = xx - rx
        local c2
        if rel == 0 or rel == rw - 1 then c2 = c_hi
        elseif v < 2 then c2 = c
        elseif rw < 6 then
          -- 细塔：梯格横档（X 斜撑在窄宽度下不成形）
          if v == math.floor(cell * 0.5) or v == math.floor(cell * 0.5) + 1 then c2 = c end
        else
          local u = rel / math.max(1, rw - 1)
          if math.abs(v / cell - u) < 0.2 or math.abs(v / cell - (1 - u)) < 0.2 then
            c2 = c_lo
          end
        end
        if c2 then img:putPixel(xx, yy, c2) end
      end
    end
  end
  for _, ht in ipairs({ 0.34, 0.56, 0.78 }) do
    local yy = top + math.floor(span * ht)
    local rw = math.max(3, math.floor(top_w + (w - top_w) * ht)) + 2
    local rx = x + math.floor((w - rw) / 2)
    for xx = rx, rx + rw - 1 do
      if xx >= 0 and xx < img.width and yy >= 0 then img:putPixel(xx, yy, c) end
    end
  end
  local tx = x + math.floor(w / 2)
  local th = px.rngInt(rng, 8, 18)
  for i = 1, th do
    local yy = top - i
    if yy >= 0 and tx >= 0 and tx < img.width then
      img:putPixel(tx, yy, (i == th) and c_hi or c)
    end
  end
end

-- 破碎高架桥（死亡搁浅式地标）：桥面 + 桥墩 + 断跨 + 垂落钢缆 + 坠落残骸
function px.viaduct(img, ramps, rng, opts)
  local ramp = ramps[opts.ramp or "stone_warm"]
  local level = opts.level or 3
  local c = px.rampColor(ramp, level)
  local c_hi = px.rampColor(ramp, level + 1)
  local c_lo = px.rampColor(ramp, math.max(1, level - 1))
  local y_deck = opts.y or 150
  local deck_h = opts.deck_h or 5
  local base = opts.base or (y_deck + 70)
  local x0, x1 = opts.x0 or 0, opts.x1 or img.width
  local gaps = {}
  if opts.broken then
    for _ = 1, (opts.broken_count or 1) do
      local gw = px.rngInt(rng, 40, 90)
      local gx_min = math.min(x0 + 20, x1 - 20)
      local gx_max = math.max(x0 + 21, x1 - gw - 20)
      local gx = px.rngInt(rng, gx_min, gx_max)
      table.insert(gaps, { gx, gx + gw })
    end
  end
  local function in_gap(xx)
    for _, gp in ipairs(gaps) do
      if xx >= gp[1] and xx <= gp[2] then return true end
    end
    return false
  end
  local function near_gap(xx)
    for _, gp in ipairs(gaps) do
      if math.abs(xx - gp[1]) <= 3 or math.abs(xx - gp[2]) <= 3 then return true end
    end
    return false
  end
  -- 桥面
  for xx = math.max(0, math.floor(x0)), math.min(img.width - 1, math.floor(x1)) do
    if not in_gap(xx) then
      local ragged = near_gap(xx)
      for yy = y_deck, y_deck + deck_h - 1 do
        local c2 = (yy == y_deck) and c_hi
          or ((yy == y_deck + deck_h - 1) and c_lo or c)
        if ragged and rng() < 0.45 then c2 = nil end
        if c2 and yy >= 0 and yy < img.height then img:putPixel(xx, yy, c2) end
      end
      if xx % 7 == 0 and not ragged then
        local yy = y_deck + deck_h
        if yy >= 0 and yy < img.height then img:putPixel(xx, yy, c_lo) end
      end
    end
  end
  -- 桥墩
  local pier = math.floor(x0) + px.rngInt(rng, 10, 30)
  while pier < x1 - 8 do
    local skip = false
    for _, gp in ipairs(gaps) do
      if pier > gp[1] - 6 and pier < gp[2] + 6 then skip = true end
    end
    if not skip then
      local pw = px.rngInt(rng, 4, 7)
      for yy = y_deck + deck_h, base do
        if yy < img.height then
          for xx = pier, pier + pw - 1 do
            if xx >= 0 and xx < img.width then
              img:putPixel(xx, yy, (xx == pier) and c_hi or c_lo)
            end
          end
        end
      end
      for xx = pier - 2, pier + pw + 1 do
        if xx >= 0 and xx < img.width and y_deck + deck_h >= 0 and y_deck + deck_h < img.height then
          img:putPixel(xx, y_deck + deck_h, c)
        end
      end
    end
    pier = pier + px.rngInt(rng, opts.pier_min or 42, opts.pier_max or 78)
  end
  -- 断口垂落钢缆
  if opts.broken then
    for _, gp in ipairs(gaps) do
      for side = 0, 1 do
        local ex = (side == 0) and gp[1] or gp[2]
        local len = px.rngInt(rng, 16, 42)
        local drop = px.rngInt(rng, 8, 24)
        for i = 0, len do
          local t = i / len
          local xx = ex + (side == 0 and -i or i)
          local yy = y_deck + deck_h + math.floor(drop * t + math.sin(t * math.pi) * 12)
          if xx >= 0 and xx < img.width and yy >= 0 and yy < img.height then
            img:putPixel(xx, yy, c_lo)
          end
        end
      end
    end
  end
  -- 坠落桥面残骸（斜躺）
  if opts.debris ~= false and #gaps > 0 then
    local gp = gaps[1]
    local dx0 = gp[1] + px.rngInt(rng, 0, 14)
    local dw = px.rngInt(rng, 26, 48)
    local dyy = base - px.rngInt(rng, 4, 16)
    for i = 0, dw do
      local xx = dx0 + i
      local yy = dyy + math.floor(i * 0.18)
      for k = 0, 3 do
        if xx >= 0 and xx < img.width and yy + k >= 0 and yy + k < img.height then
          img:putPixel(xx, yy + k, (k == 0) and c_hi or c)
        end
      end
    end
  end
end

-- 巨构天际线（多形制、可超框、可巨型）
-- opts: x0/x1/y(基线), hmin/hmax, wmin/wmax, gapmin/gapmax, ramp, level,
--       styles = {"tower","frame","tank","arcology","gantry",...},
--       colossal = true + colossal_prob/colossal_scale（顶部超出画框的巨型剪影）
function px.megastructure(img, ramps, rng, opts)
  local base = opts.y or math.floor(img.height * 0.6)
  local x = opts.x0 or 0
  local x1 = opts.x1 or img.width
  local ramp = ramps[opts.ramp or "iron"]
  local level = opts.level or 3
  local styles = opts.styles or { "tower", "tower", "frame", "tank", "arcology", "gantry" }
  while x < x1 do
    local style = styles[px.rngInt(rng, 1, #styles)]
    local w = px.rngInt(rng, opts.wmin or 10, opts.wmax or 24)
    local h = px.rngInt(rng, opts.hmin or 50, opts.hmax or 115)
    if opts.colossal and rng() < (opts.colossal_prob or 0.18) then
      h = math.floor(h * (opts.colossal_scale or 2.0))
      w = math.floor(w * (opts.colossal_width_scale or 1.15))
    end
    local top = base - h
    local g = { x = x, w = w, top = top, base = base, ramp = ramp, level = level }
    if style == "frame" then mega_frame(img, ramps, rng, g)
    elseif style == "tank" then mega_tank(img, ramps, rng, g)
    elseif style == "arcology" then mega_arcology(img, ramps, rng, g)
    elseif style == "gantry" then mega_gantry(img, ramps, rng, g)
    elseif style == "block" then mega_block(img, ramps, rng, g)
    elseif style == "hall" then mega_hall(img, ramps, rng, g)
    elseif style == "mast" then mega_mast(img, ramps, rng, g)
    else mega_tower(img, ramps, rng, g) end
    x = x + w + px.rngInt(rng, opts.gapmin or 6, opts.gapmax or 20)
  end
end

-- 悬索/斜拉索：横跨天际的悬链线（巨构之间的史诗尺度线索）
function px.mega_cable(img, ramps, opts)
  local c = px.rampColor(ramps[opts.ramp or "iron"], opts.level or 2)
  local x0 = opts.x0 or 0
  local x1 = opts.x1 or img.width
  local y0 = opts.y0 or 100
  local y1 = opts.y1 or y0
  local sag = opts.sag or 30
  local steps = math.floor(x1 - x0)
  for i = 0, steps do
    local t = i / math.max(1, steps)
    local xx = math.floor(x0 + (x1 - x0) * t)
    local yy = math.floor(y0 + (y1 - y0) * t + sag * 4 * t * (1 - t))
    if xx >= 0 and xx < img.width and yy >= 0 and yy < img.height then
      img:putPixel(xx, yy, c)
    end
    -- 吊杆（向下垂）
    if opts.hangers and i % opts.hangers == 0 and t > 0.06 and t < 0.94 then
      for d = 1, opts.hanger_len or 4 do
        local hy = yy + d
        if xx >= 0 and xx < img.width and hy >= 0 and hy < img.height then
          img:putPixel(xx, hy, c)
        end
      end
    end
  end
end

-- 鸟群：尺度参照（微小剪影，随相位缓慢漂移）
function px.birds(img, ramps, rng, opts)
  local c = px.rampColor(ramps[opts.ramp or "shadow"], opts.level or 2)
  local phase = opts.phase or 0
  for fl = 1, (opts.flocks or 2) do
    local fx = px.rngInt(rng, opts.x0 or 0, opts.x1 or img.width)
    local fy = px.rngInt(rng, opts.y0 or 30, opts.y1 or 120)
    local n = px.rngInt(rng, 3, 7)
    for b = 1, n do
      local bx = fx + px.rngInt(rng, -16, 16) + math.floor(math.sin(phase + b) * 2)
      local by = fy + px.rngInt(rng, -7, 7) + math.floor(math.cos(phase * 0.7 + b))
      if bx >= 1 and bx < img.width - 1 and by >= 1 and by < img.height then
        img:putPixel(bx, by, c)
        img:putPixel(bx - 1, by - 1, c)
        img:putPixel(bx + 1, by - 1, c)
      end
    end
  end
end

-- 云层：软边抖动云带（覆盖在天空上）
function px.clouds(img, ramps, rng, opts)
  local ramp = ramps[opts.ramp or "bone"]
  local count = opts.count or 3
  local dens = opts.density or 0.5
  for i = 1, count do
    local cy = px.rngInt(rng, opts.y0 or 30, opts.y1 or 90)
    local cx = px.rngInt(rng, 0, img.width)
    local w = px.rngInt(rng, opts.wmin or 40, opts.wmax or 130)
    local hh = px.rngInt(rng, opts.hmin or 5, opts.hmax or 13)
    for dy = -hh, hh do
      local t = 1 - math.abs(dy) / hh       -- 中央最密
      local row_w = w * (0.55 + 0.45 * t)
      local y = cy + dy
      if y >= 0 and y < img.height then
        for dx = -row_w, row_w do
          local x = cx + dx
          if x >= 0 and x < img.width then
            local p = dens * t * (0.55 + 0.45 * math.sin(dx * 0.15 + i * 2))
            if px.bayer(x, y) < p then
              img:putPixel(x, y, px.rampColor(ramp, t > 0.6 and 5 or 4))
            end
          end
        end
      end
    end
  end
end

-- 大气雾：从 y0 向上按深度梯度混向雾 ramp（有序抖动）；field 可完全自定义
function px.fog(img, index, ramps, opts)
  local ramp = ramps[opts.ramp or "frost"]
  local y0 = opts.y0 or img.height * 0.5
  local strength = opts.strength or 0.7
  local field = opts.field
  local level0 = opts.baseLevel or 3
  local levelSpan = opts.levelSpan or 2
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local c = img:getPixel(x, y)
      if app.pixelColor.rgbaA(c) > 0 and index[c] then
        local t
        if field then t = field(x, y)
        else t = math.max(0, (y - y0) / math.max(1, img.height - y0)) end
        t = t * strength
        if t > 0 and (BAYER4[(y % 4) + 1][(x % 4) + 1] / 16.0) < t then
          img:putPixel(x, y, px.rampColor(ramp, level0 + math.floor(t * levelSpan + 0.5)))
        end
      end
    end
  end
end

-- 星空（含相位闪烁；同 seed 基础分布不变）
function px.stars(img, ramps, rng, opts)
  local ramp = ramps[opts.ramp or "frost"]
  local ymax = opts.ymax or img.height * 0.5
  local count = opts.count or 60
  local levels = opts.levels or { 3, 4, 5 }
  local phase = opts.phase or 0
  for i = 1, count do
    local x = px.rngInt(rng, 0, img.width - 1)
    local y = px.rngInt(rng, 0, math.max(0, math.floor(ymax)))
    local lv = px.pick(rng, levels)
    local tw = math.sin(phase * 3 + i * 1.7)   -- 3 个周期/循环：无缝且帧间可见
    if tw > -0.3 then
      img:putPixel(x, y, px.rampColor(ramp, lv))
      if lv >= 4 and rng() < 0.1 and x + 1 < img.width then
        img:putPixel(x + 1, y, ramp[3])
      end
    end
  end
end

-- 月盘（含抖动光晕；corrupt=true 时渐染为余烬色 = 血月）
function px.moonDisc(img, index, ramps, cx, cy, r, opts)
  opts = opts or {}
  local ramp = ramps[opts.ramp or "frost"]
  local glowRamp = ramps[opts.glowRamp or (opts.corrupt and "ember" or opts.ramp or "frost")]
  local glow = opts.glow or math.floor(r * 1.6)
  local corrupt = opts.corrupt
  local rng = opts.rng or px.rng(1)
  -- 光晕：对天空像素提亮（抖动环，幂衰减）
  for y = math.floor(cy - r - glow), math.ceil(cy + r + glow) do
    for x = math.floor(cx - r - glow), math.ceil(cx + r + glow) do
      if x >= 0 and y >= 0 and x < img.width and y < img.height then
        local dx, dy = x - cx, y - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d > r and d < r + glow then
          local t = 1 - (d - r) / glow
          t = t ^ 1.4
          local c = img:getPixel(x, y)
          local info = index[c]
          if info and (BAYER4[(y % 4) + 1][(x % 4) + 1] / 16.0) < math.min(0.7, t * 1.1) then
            local src_ramp = corrupt and glowRamp or ramps[info.ramp]
            local boost = t > 0.55 and 2 or 1
            local base_level = corrupt and math.min(2, info.level) or info.level
            img:putPixel(x, y, px.rampColor(src_ramp, base_level + boost))
          end
        end
      end
    end
  end
  -- 月体：外环 4、内盘 5、陨坑 3（corrupt = 余烬色血月）
  local body_ramp = corrupt and ramps["ember"] or ramp
  for y = math.floor(cy - r), math.ceil(cy + r) do
    for x = math.floor(cx - r), math.ceil(cx + r) do
      if x >= 0 and y >= 0 and x < img.width and y < img.height then
        local dx, dy = x - cx, y - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= r then
          local lv = d > r * 0.82 and 4 or 5
          img:putPixel(x, y, px.rampColor(body_ramp, lv))
        end
      end
    end
  end
  local craters = math.floor(r * 0.8)
  for _ = 1, craters do
    local ang = rng() * math.pi * 2
    local dist = rng() * r * 0.75
    local hx = math.floor(cx + math.cos(ang) * dist)
    local hy = math.floor(cy + math.sin(ang) * dist * 0.9)
    if hx >= 0 and hy >= 0 and hx < img.width and hy < img.height then
      img:putPixel(hx, hy, body_ramp[3])
      if rng() < 0.4 then img:putPixel(hx + 1, hy, body_ramp[3]) end
    end
  end
end

-- 远景山脊剪影（中点位移）。only_empty=true 不覆盖已有像素
function px.ridge(img, ramps, rng, opts)
  local ramp = ramps[opts.ramp or "shadow"]
  local level = opts.level or 2
  local base = opts.y or img.height * 0.5
  local amp = opts.amplitude or 20
  local w = img.width
  local pts = { [0] = base + (rng() - 0.5) * amp, [w - 1] = base + (rng() - 0.5) * amp }
  local function subdivide(x0, x1)
    if x1 - x0 <= 1 then return end
    local mid = math.floor((x0 + x1) / 2)
    pts[mid] = (pts[x0] + pts[x1]) / 2 + (rng() - 0.5) * amp * 0.55
    subdivide(x0, mid)
    subdivide(mid, x1)
  end
  subdivide(0, w - 1)
  local color = px.rampColor(ramp, level)
  local color_hi = px.rampColor(ramp, level + 1)
  for x = 0, w - 1 do
    local top = math.floor(pts[x] or base)
    for y = top, img.height - 1 do
      if (not opts.only_empty) or app.pixelColor.rgbaA(img:getPixel(x, y)) == 0 then
        -- 脊线一对像素略亮，制造体积感
        img:putPixel(x, y, (y <= top + 1 and rng() < 0.5) and color_hi or color)
      end
    end
  end
end

-- 远树线剪影（丛生起伏的针叶/阔叶混排，低矮蓬松）
function px.treeline(img, ramps, rng, opts)
  local ramp = ramps[opts.ramp or "shadow"]
  local level = opts.level or 2
  local base = opts.y or img.height * 0.5
  local height = opts.height or 14
  local color = px.rampColor(ramp, level)
  local x = 0
  while x < img.width do
    local th = height * px.rngRange(rng, 0.45, 1.15)
    local tw = px.rngInt(rng, 5, 11)
    local cx = x + tw / 2
    local conifer = rng() < 0.55
    for iy = 0, math.floor(th) do
      local yy = math.floor(base - iy)
      if yy >= 0 and yy < img.height then
        local half
        if conifer then
          -- 针叶：微凹的三角形（底宽顶窄），带 1px 摇摆
          local k = iy / math.max(1, th)
          half = (tw / 2) * (0.55 + 0.45 * (1 - k)) * math.sqrt(math.max(0.05, 1 - k * k * 0.6))
        else
          local k = iy / math.max(1, th)
          half = (tw / 2) * math.sqrt(math.max(0, 1 - k * k))
        end
        local wob = (rng() - 0.5) * 1.2
        for ix = math.floor(cx - half + wob), math.ceil(cx + half + wob) do
          if ix >= 0 and ix < img.width
            and ((not opts.only_empty) or app.pixelColor.rgbaA(img:getPixel(ix, yy)) == 0) then
            img:putPixel(ix, yy, color)
          end
        end
      end
    end
    x = x + math.floor(tw * 0.55) + px.rngInt(rng, 0, 2)  -- 树冠重叠成丛
  end
  -- 基线填充
  for xx = 0, img.width - 1 do
    for yy = math.floor(base), img.height - 1 do
      if (not opts.only_empty) or app.pixelColor.rgbaA(img:getPixel(xx, yy)) == 0 then
        img:putPixel(xx, yy, color)
      end
    end
  end
end

-- 光束：从 (x,y) 向 angle 方向发散 count 条，交错抖动 + 距离衰减
-- opts.ramp 指定时直接铺该 ramp 色（level_base 控制亮度基准）；否则对原像素提亮一阶
function px.rays(img, index, ramps, rng, opts)
  local count = opts.count or 4
  local base = opts.angle or (math.pi / 2)
  local spread = opts.spread or 0.5
  local length = opts.length or img.height
  local strength = opts.strength or 0.5
  local step = opts.step or 3
  local level_base = opts.level_base or 1
  local override = opts.ramp and ramps[opts.ramp]
  for i = 1, count do
    local a = base + px.rngRange(rng, -spread, spread)
    local width = px.rngRange(rng, 1.5, 4.0)
    local steps = math.floor(length / step)
    for s = 1, steps do
      local d = s * step
      local cx = opts.x + math.cos(a) * d
      local cy = opts.y + math.sin(a) * d
      local fade = strength * (1 - s / steps) * px.rngRange(rng, 0.75, 1.25)
      local w_ = width + d * 0.03
      for o = -w_, w_, 0.9 do
        local rx = math.floor(cx + math.cos(a + math.pi / 2) * o)
        local ry = math.floor(cy + math.sin(a + math.pi / 2) * o)
        if rx >= 0 and ry >= 0 and rx < img.width and ry < img.height then
          local c = img:getPixel(rx, ry)
          local info = index[c]
          if info and (BAYER4[(ry % 4) + 1][(rx % 4) + 1] / 16.0) < math.min(0.9, fade) then
            if override then
              img:putPixel(rx, ry, px.rampColor(override,
                level_base + math.floor(math.min(0.95, fade) * 3.5)))
            else
              img:putPixel(rx, ry, px.rampColor(ramps[info.ramp], info.level + 1))
            end
          end
        end
      end
    end
  end
end

-- 余烬/萤火粒子（烘入画面；同 seed 同分布，相位推进运动）
function px.embers(img, ramps, rng, opts)
  local ramp = ramps[opts.ramp or "ember"]
  local index = opts.index
  local count = opts.count or 20
  local x0, x1 = opts.x0 or 0, opts.x1 or img.width
  local y0, y1 = opts.y0 or 0, opts.y1 or img.height
  local phase = opts.phase or 0
  local rise = opts.rise or 46
  for i = 1, count do
    local bx = px.rngRange(rng, x0, x1)
    local by = px.rngRange(rng, y0, y1)
    local sp = px.rngRange(rng, 0.5, 1.2)
    local drift = px.rngRange(rng, -0.5, 0.5)
    local prog = ((phase / (2 * math.pi)) + i * 0.137) % 1.0
    local ix = math.floor(bx + math.sin(phase + i) * 3 + drift * prog * 12)
    local iy = math.floor(by - prog * rise * sp)
    local bright = math.sin(prog * math.pi)
    if bright > 0.15 and ix >= 0 and iy >= 0 and ix < img.width and iy < img.height then
      local lv = (bright > 0.75) and 5 or ((bright > 0.42) and 4 or 3)
      img:putPixel(ix, iy, px.rampColor(ramp, lv))
      -- 主粒下方一点残晖
      if bright > 0.6 and iy + 1 < img.height then
        local below = img:getPixel(ix, iy + 1)
        local info2 = index and index[below]
        if info2 and info2.ramp == opts.ramp then
          img:putPixel(ix, iy + 1, px.rampColor(ramp, math.max(1, lv - 2)))
        end
      end
    end
  end
end

-- ============================================================ Image / 保存

function px.newImage(w, h)
  local img = Image(w, h, ColorMode.RGB)
  img:clear(px.rgba(0, 0, 0, 0))
  return img
end

function px.save(img, path)
  img:saveAs(path)
end

-- ============================================================ 参数 / JSON

function px.params()
  local t = {}
  if app.params then
    for k, v in pairs(app.params) do t[k] = v end
  end
  return t
end

function px.split(text, sep)
  local out = {}
  sep = sep or ";"
  for piece in tostring(text):gmatch("([^" .. sep .. "]+)") do
    table.insert(out, piece)
  end
  return out
end

-- "k=v;k=v" → {k="v"}
function px.parseKV(text)
  local t = {}
  if not text or text == "" then return t end
  for _, piece in ipairs(px.split(text, ";")) do
    local k, v = piece:match("^([^=]+)=(.*)$")
    if k then t[k] = v end
  end
  return t
end

function px.tonum(v, default)
  local n = tonumber(v)
  if n == nil then return default end
  return n
end

function px.tobool(v, default)
  if v == nil then return default end
  v = tostring(v):lower()
  return v == "true" or v == "1" or v == "yes"
end

local function esc(s)
  return '"' .. tostring(s):gsub('[%c"\\]', function(ch)
    if ch == '"' then return '\\"'
    elseif ch == "\\" then return "\\\\"
    elseif ch == "\n" then return "\\n"
    else return string.format("\\u%04x", ch:byte()) end
  end) .. '"'
end

local function enc(v)
  local t = type(v)
  if t == "nil" then return "null"
  elseif t == "boolean" or t == "number" then return tostring(v)
  elseif t == "string" then return esc(v)
  elseif t == "table" then
    if v[1] ~= nil then
      local parts = {}
      for _, item in ipairs(v) do table.insert(parts, enc(item)) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for k, item in pairs(v) do
      table.insert(parts, esc(k) .. ":" .. enc(item))
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

px.jsonEncode = enc

function px.emit(tbl)
  print("FORGE:" .. enc(tbl))
end

return px
