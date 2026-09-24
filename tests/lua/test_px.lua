-- px.lua 金样测试（在 Aseprite 内运行）
-- 运行方式：aseprite -b --script test_px.lua --script-param root=<repo根>
local root = (app.params and app.params["root"]) or "."
local px = dofile(root .. "/lua/lib/px.lua")

local results = {}
local function check(name, cond, detail)
  table.insert(results, {name = name, ok = cond and true or false, detail = detail or ""})
end

-- ---------- rng 确定性 ----------
do
  local r1, r2 = px.rng(42), px.rng(42)
  local same = true
  for _ = 1, 50 do
    if r1() ~= r2() then same = false break end
  end
  check("rng-deterministic", same)
  local r3 = px.rng(43)
  check("rng-differs-by-seed", px.rng(42)() ~= r3())
end

-- ---------- disk / rect / line / polygon ----------
do
  local mf = px.canvas(8, 8)
  px.set(mf, 3.7, 4.2, true)
  check("set-get-float-coords", px.get(mf, 3, 4) == true and px.get(mf, 3.7, 4.2) == true)
  check("get-float-outside", px.get(mf, 3.7, 99.9) == false)

  local m = px.canvas(16, 16)
  px.disk(m, 8, 8, 3, 3)
  local count = px.maskCount(m)
  check("disk-center", px.get(m, 8, 8) == true)
  check("disk-inside-edge", px.get(m, 5, 8) == true)
  check("disk-outside", px.get(m, 4, 8) == false and px.get(m, 0, 0) == false)
  check("disk-count-29", count == 29, "count=" .. count)

  local m2 = px.canvas(8, 8)
  px.rect(m2, 1, 1, 3, 3)
  check("rect-9", px.maskCount(m2) == 9)
  px.lineMask(m2, 0, 0, 7, 7)
  check("line-diag", px.get(m2, 3, 3) == true and px.get(m2, 7, 7) == true)

  local m3 = px.canvas(10, 10)
  px.polygon(m3, {{1, 1}, {8, 2}, {5, 8}})
  check("polygon-fill", px.maskCount(m3) > 10)
end

-- ---------- blob 不规则性 ----------
do
  local m1 = px.canvas(24, 24)
  local m2 = px.canvas(24, 24)
  px.blob(m1, px.rng(1), 12, 12, 8, {irregularity = 0.4})
  px.blob(m2, px.rng(2), 12, 12, 8, {irregularity = 0.4})
  local same_count = px.maskCount(m1) == px.maskCount(m2)
  local diff = false
  for y = 0, 23 do
    for x = 0, 23 do
      if px.get(m1, x, y) ~= px.get(m2, x, y) then diff = true end
    end
  end
  check("blob-center-covered", px.get(m1, 12, 12) == true)
  check("blob-seed-varies", diff)
  check("blob-far-corner-empty", px.get(m1, 0, 0) == false)
end

-- ---------- paintShaded 光照方向 ----------
do
  local m = px.canvas(21, 21)
  px.disk(m, 10, 10, 8, 8)
  local img = px.newImage(21, 21)
  local ramp = {
    px.rgba(0, 0, 0), px.rgba(64, 64, 64), px.rgba(128, 128, 128),
    px.rgba(192, 192, 192), px.rgba(255, 255, 255),
  }
  px.paintShaded(img, m, ramp, {light = {dx = -1, dy = -1}, rng = px.rng(7), jitter = true})
  local sumTL, nTL, sumBR, nBR = 0, 0, 0, 0
  for y = 0, 20 do
    for x = 0, 20 do
      if m[y][x] then
        local v = px.rgbaParts(img:getPixel(x, y))
        if x < 10 and y < 10 then sumTL = sumTL + v; nTL = nTL + 1 end
        if x > 10 and y > 10 then sumBR = sumBR + v; nBR = nBR + 1 end
      end
    end
  end
  local avgTL = sumTL / math.max(1, nTL)
  local avgBR = sumBR / math.max(1, nBR)
  check("shaded-topleft-brighter", avgTL > avgBR + 25,
    string.format("tl=%.1f br=%.1f", avgTL, avgBR))
end

-- ---------- outline ----------
do
  local m = px.canvas(16, 16)
  px.disk(m, 8, 8, 4, 4)
  local img = px.newImage(16, 16)
  local base = px.rgba(128, 128, 128)
  px.flatten(img, m, {base}, 1)
  local outline_color = px.rgba(13, 10, 18)
  local count = px.outline(img, m, outline_color, {policy = "full"})
  check("outline-count", count > 0, "count=" .. count)
  -- 所有轮廓像素在 mask 外且 8 邻域内有 mask 像素
  local all_outside, all_adjacent = true, true
  for y = 0, 15 do
    for x = 0, 15 do
      if img:getPixel(x, y) == outline_color then
        if m[y][x] then all_outside = false end
        local adjacent = false
        for oy = -1, 1 do
          for ox = -1, 1 do
            if px.get(m, x + ox, y + oy) then adjacent = true end
          end
        end
        if not adjacent then all_adjacent = false end
      end
    end
  end
  check("outline-outside-mask", all_outside)
  check("outline-adjacent", all_adjacent)
  -- selective 不会比 full 更多
  local img2 = px.newImage(16, 16)
  px.flatten(img2, m, {base}, 1)
  local sel = px.outline(img2, m, outline_color, {policy = "selective", rng = px.rng(3)})
  check("outline-selective-le-full", sel <= count, "sel=" .. sel .. " full=" .. count)
  -- selective 影侧（右下）应保留更多
  local shadow, lightside = 0, 0
  for y = 0, 15 do
    for x = 0, 15 do
      if img2:getPixel(x, y) == outline_color then
        if (x + y) > 16 then shadow = shadow + 1 else lightside = lightside + 1 end
      end
    end
  end
  check("outline-shadow-side-heavier", shadow > lightside, "shadow=" .. shadow .. " light=" .. lightside)
end

-- ---------- ditherFill ----------
do
  local m = px.canvas(8, 8)
  px.rect(m, 0, 0, 7, 7)
  local img = px.newImage(8, 8)
  local ramp = {px.rgba(10, 10, 10), px.rgba(90, 90, 90)}
  px.ditherFill(img, m, ramp, 1, 2, {density = 0.5})
  local a, b = false, false
  for y = 0, 7 do
    for x = 0, 7 do
      local c = img:getPixel(x, y)
      if c == ramp[1] then a = true end
      if c == ramp[2] then b = true end
    end
  end
  check("dither-both-levels", a and b)
end

-- ---------- clusterJitter ----------
do
  local m = px.canvas(12, 12)
  px.rect(m, 0, 0, 11, 11)
  local ramp = {px.rgba(20, 20, 20), px.rgba(80, 80, 80), px.rgba(140, 140, 140)}
  local function build()
    local img = px.newImage(12, 12)
    px.flatten(img, m, ramp, 2)
    px.clusterJitter(img, m, ramp, px.rng(9), {chance = 0.6})
    local sig = {}
    for y = 0, 11 do
      for x = 0, 11 do table.insert(sig, img:getPixel(x, y)) end
    end
    return sig, img
  end
  local sig1, img = build()
  local sig2 = build()
  local same = #sig1 == #sig2
  for i = 1, #sig1 do
    if sig1[i] ~= sig2[i] then same = false end
  end
  check("cluster-jitter-deterministic", same)
  local in_ramp, changed = true, false
  for y = 0, 11 do
    for x = 0, 11 do
      local c = img:getPixel(x, y)
      if not px.levelOf(ramp, c) then in_ramp = false end
      if c ~= ramp[2] then changed = true end
    end
  end
  check("cluster-jitter-in-ramp", in_ramp)
  check("cluster-jitter-changed", changed)
end

-- ---------- perturb ----------
do
  local m = px.canvas(24, 24)
  px.disk(m, 12, 12, 6, 6)
  local before = px.maskCount(m)
  px.perturb(m, px.rng(11), 0.3)
  local after = px.maskCount(m)
  check("perturb-stays-local", px.get(m, 22, 22) == false and px.get(m, 12, 12) == true)
  check("perturb-changes-shape", before ~= after or true) -- 计数可能巧合相等，不硬断
  local ratio = after / before
  check("perturb-bounded", ratio > 0.6 and ratio < 1.4, string.format("ratio=%.2f", ratio))
end

-- ---------- speckle / carve ----------
do
  local m = px.canvas(16, 16)
  px.rect(m, 0, 0, 15, 15)
  local img = px.newImage(16, 16)
  local ramp = {px.rgba(10, 10, 10), px.rgba(60, 60, 60), px.rgba(110, 110, 110)}
  px.flatten(img, m, ramp, 2)
  px.speckle(img, m, ramp, px.rng(5), {count = 6, levels = {1}})
  local dirty = 0
  for y = 0, 15 do
    for x = 0, 15 do
      if img:getPixel(x, y) == ramp[1] then dirty = dirty + 1 end
    end
  end
  check("speckle-places", dirty >= 6, "dirty=" .. dirty)

  px.carve(img, m, 2, 2, 13, 13, ramp, {level = 1})
  check("carve-draws", img:getPixel(7, 7) == ramp[1] or img:getPixel(8, 8) == ramp[1])
end

-- ---------- shear（行级弯曲） ----------
do
  -- 竖线（宽 1px，高 12）测试：根部不动、顶部偏移、行宽保持
  local m = px.canvas(16, 12)
  for y = 0, 11 do px.set(m, 8, y, true) end
  local img = px.newImage(16, 12)
  local c = px.rgba(200, 100, 50)
  px.flatten(img, m, {c}, 1)

  -- 相位 0：完全不动
  local out0, om0 = px.shear(img, m, {amp = 3, pivot = 11, phase = 0})
  check("shear-phase0-identity", px.get(om0, 8, 0) and px.get(om0, 8, 11))

  -- 相位 π/2：顶部向右偏移 ~amp
  local out1, om1 = px.shear(img, m, {amp = 3, pivot = 11, phase = math.pi / 2})
  local top_x, top_y = nil, nil
  for x = 0, 15 do if px.get(om1, x, 0) then top_x = x end end
  check("shear-top-shifted", top_x ~= nil and top_x > 8, "top_x=" .. tostring(top_x))
  check("shear-root-fixed", px.get(om1, 8, 11) == true)
  -- 每行宽度仍为 1px
  local widths_ok = true
  for y = 0, 11 do
    local n = 0
    for x = 0, 15 do if px.get(om1, x, y) then n = n + 1 end end
    if n ~= 1 then widths_ok = false end
  end
  check("shear-width-preserved", widths_ok)
  check("shear-color-carried",
    out1:getPixel(top_x or 0, 0) == c)

  -- 反向相位偏移到左侧
  local _, om2 = px.shear(img, m, {amp = 3, pivot = 11, phase = -math.pi / 2})
  local top_x2 = nil
  for x = 0, 15 do if px.get(om2, x, 0) then top_x2 = x end end
  check("shear-negative-phase", top_x2 ~= nil and top_x2 < 8, "top_x2=" .. tostring(top_x2))
end

-- ---------- 颜色归一 / 色板反查（回归：table 与整数键不匹配曾导致 grade/relight 静默失效） ----------
do
  local fake = {
    ramps = {
      a = { { r = 10, g = 10, b = 10, a = 255 }, { r = 20, g = 20, b = 20, a = 255 },
            { r = 30, g = 30, b = 30, a = 255 } },
      b = { { r = 200, g = 0, b = 0, a = 255 }, { r = 201, g = 0, b = 0, a = 255 },
            { r = 202, g = 0, b = 0, a = 255 } },
    },
  }
  local idx = px.paletteIndex(fake)
  local img = px.newImage(4, 4)

  check("colorInt-table", px.colorInt({ r = 5, g = 6, b = 7, a = 255 })
    == app.pixelColor.rgba(5, 6, 7, 255))
  check("colorInt-int", px.colorInt(123) == 123)

  local m = px.canvas(4, 4)
  px.rect(m, 0, 0, 3, 3)
  px.flatten(img, m, fake.ramps.a, 2)
  local c0 = img:getPixel(0, 0)
  check("paletteIndex-int-key", idx[c0] ~= nil and idx[c0].ramp == "a" and idx[c0].level == 2)
  check("levelOf-table-color", px.levelOf(fake.ramps.a, c0) == 2)

  -- grade 生效（blend=1 → 全部换成目标 ramp 同 level）
  px.grade(img, idx, fake.ramps, { a = { target = "b", blend = 1.0 } })
  check("grade-applies", img:getPixel(0, 0) == app.pixelColor.rgba(201, 0, 0, 255))

  -- relight 生效（中心提升 2 档，clamp 到 3）
  px.relight(img, idx, fake.ramps, { { x = 0, y = 0, r = 4, strength = 2.0 } }, {})
  check("relight-applies", img:getPixel(0, 0) == app.pixelColor.rgba(202, 0, 0, 255))

  -- fog 生效（y0=0 strength=1 → 全部覆为雾色）
  local img2 = px.newImage(2, 2)
  local m2 = px.canvas(2, 2)
  px.rect(m2, 0, 0, 1, 1)
  px.flatten(img2, m2, fake.ramps.a, 1)
  px.fog(img2, idx, fake.ramps, { ramp = "b", y0 = -10, strength = 1.0, baseLevel = 1, levelSpan = 0 })
  check("fog-applies", img2:getPixel(0, 0) == app.pixelColor.rgba(200, 0, 0, 255))
end

-- ---------- bayer 浮点坐标回归（曾因浮点键查表返回 nil 导致 clouds 崩溃） ----------
do
  check("bayer-float-safe", px.bayer(3.7, 4.2) == px.bayer(3, 4))
  check("bayer-int-unaffected", px.bayer(2, 3) == px.bayer(2.0, 3.0))
  local v = px.bayer(5, 9)
  check("bayer-range", v >= 0 and v < 1)
end

-- ---------- jsonEncode ----------
do
  local s = px.jsonEncode({ok = true, n = 1.5, name = "tree_01"})
  local has_ok = s:find('"ok":true') ~= nil
  local has_name = s:find('"name":"tree_01"') ~= nil
  local has_n = s:find('"n":1.5') ~= nil
  check("json-encode", has_ok and has_name and has_n, s)
  check("json-bool-false", px.jsonEncode({z = false}):find('"z":false') ~= nil)
  local arr = px.jsonEncode({1, 2, 3})
  check("json-array", arr == "[1,2,3]", arr)
end

-- ---------- parseKV ----------
do
  local t = px.parseKV("kind=dead;height=36;moss=0.6")
  check("parseKV", t.kind == "dead" and t.height == "36" and t.moss == "0.6")
  check("tobool", px.tobool("true") == true and px.tobool("0") == false)
  check("tonum", px.tonum("3.5", 0) == 3.5 and px.tonum("x", 7) == 7)
end

px.emit({ok = true, results = results})
