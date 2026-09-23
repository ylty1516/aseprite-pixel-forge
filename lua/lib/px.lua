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
  for i, c in ipairs(ramp) do
    if c == color then return i end
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
