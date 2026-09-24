-- scene.lua — 场景渲染器（《王国》式大气光影 / 视差纵深 / 叙事构图）
-- 参数（--script-param，均须位于 --script 之前）：
--   lib/style/scene/out/pack 必填；frames/fps/time/size 可选覆盖场景谱
-- 场景谱：scenes/*.lua 返回 { name, size, seed, frames, fps, time, layers={...}, grades={...} }
-- 输出：帧 PNG + 多帧 .aseprite + FORGE:{"ok":...,"files":{...},"frames":N}

local function fallback_emit(msg)
  local s = tostring(msg):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
  print('FORGE:{"ok":false,"error":"' .. s .. '"}')
end

local function run()
  local P = app.params or {}

  local function need(key)
    local v = P[key]
    if v == nil or v == "" then error("缺少 --script-param " .. key, 2) end
    return v
  end

  local px = dofile(need("lib"))
  local style = dofile(need("style"))
  local scene = dofile(need("scene"))
  local pack = P["pack"] or ""
  local out = P["out"] or "."

  local W, H = scene.size[1], scene.size[2]
  if P["size"] then
    local sw, sh = tostring(P["size"]):match("^(%d+)x(%d+)$")
    if sw then W, H = tonumber(sw), tonumber(sh) end
  end
  local frames = math.floor(px.tonum(P["frames"] or scene.frames or 1, 1))
  frames = math.max(1, math.min(16, frames))
  local fps = px.tonum(P["fps"] or scene.fps or 8, 8)
  if fps <= 0 then fps = 8 end
  local seed = scene.seed or 20260923
  local ramps = style.ramps
  local index = px.paletteIndex(style)

  -- 时段变体（times 表）：可换天光/隐藏图层/改雾/换调色预设/月球色
  local time_name = P["time"] or scene.time or "day"
  local tc = (scene.times or {})[time_name] or {}
  local function hidden(tp)
    for _, h in ipairs(tc.hide or {}) do
      if h == tp then return true end
    end
    return false
  end

  -- 素材缓存（以 cel 图像尺寸为准：Aseprite 中画布与 cel 可能不同，如裁剪后的 cel）
  local sprite_cache = {}
  local function load_sprite(folder, name)
    local key = folder .. "/" .. name
    if sprite_cache[key] then return sprite_cache[key] end
    local path = pack .. "/" .. folder .. "/" .. name .. ".png"
    local spr = app.open(path)
    if not spr then error("无法打开素材：" .. path) end
    local src = spr.cels[1].image
    local img = px.newImage(src.width, src.height)
    for y = 0, src.height - 1 do
      for x = 0, src.width - 1 do
        img:putPixel(x, y, src:getPixel(x, y))
      end
    end
    spr:close()
    sprite_cache[key] = img
    return img
  end

  local function render_frame(f)
    local phase = (f - 1) / frames * math.pi * 2
    local img = px.newImage(W, H)
    local li = 0
    for _, layer in ipairs(scene.layers or {}) do
      li = li + 1
      local t = layer.type
      if hidden(t) then goto continue end
      local function layer_rng()
        return px.rng(seed + li * 977)
      end

      if t == "sky" then
        local ramp = ramps[tc.sky_ramp or layer.ramp or "shadow"]
        local from, to = tc.sky_from or layer.from or 1, tc.sky_to or layer.to or 3
        for y = 0, H - 1 do
          local tt = y / math.max(1, H - 1)
          local lvf = from + (to - from) * tt
          local base_lv = math.floor(lvf)
          local frac = lvf - base_lv
          for x = 0, W - 1 do
            local lv = base_lv
            if frac > 0 and px.bayer(x, y) < frac then lv = base_lv + 1 end
            img:putPixel(x, y, px.rampColor(ramp, lv))
          end
        end

      elseif t == "stars" then
        px.stars(img, ramps, layer_rng(), {
          ramp = layer.ramp, ymax = layer.ymax or H * 0.5,
          count = layer.count or 60, phase = phase,
        })

      elseif t == "moon" then
        local corrupt = layer.corrupt
        if tc.moon_corrupt ~= nil then corrupt = tc.moon_corrupt end
        px.moonDisc(img, index, ramps, layer.x, layer.y, layer.r, {
          glow = layer.glow, corrupt = corrupt, ramp = tc.moon_ramp or layer.ramp,
          glowRamp = layer.glow_ramp, rng = layer_rng(),
        })

      elseif t == "ridge" then
        px.ridge(img, ramps, layer_rng(), {
          y = layer.y, amplitude = layer.amplitude or 20,
          ramp = layer.ramp or "shadow", level = layer.level or 2,
          only_empty = layer.only_empty,
        })

      elseif t == "treeline" then
        px.treeline(img, ramps, layer_rng(), {
          y = layer.y, height = layer.height or 18,
          ramp = layer.ramp or "shadow", level = layer.level or 2,
          only_empty = layer.only_empty,
        })

      elseif t == "ground" then
        local tile_names = layer.tiles or { layer.tile }
        local grng = layer_rng()
        local tiles_l = {}
        for i, nm in ipairs(tile_names) do
          tiles_l[i] = load_sprite(layer.folder or "tiles", nm)
        end
        for ty = (layer.y or 0), H - 1, 32 do
          for tx = 0, W - 1, 32 do
            local tile = tiles_l[px.rngInt(grng, 1, #tiles_l)]
            px.blit(img, tile, tx, ty)
          end
        end

      elseif t == "sprite" then
        local s = load_sprite(layer.folder, layer.name)
        local x, y = layer.x, layer.y
        if (layer.anchor or "bottom_center") == "bottom_center" then
          x = x - math.floor(s.width / 2)
          y = y - s.height
        end
        px.blit(img, s, x, y)

      elseif t == "grade" then
        local spec = layer.spec
          or (scene.grades and scene.grades[tc.grade or layer.preset or scene.time or "day"])
          or {}
        px.grade(img, index, ramps, spec, {})

      elseif t == "light" then
        -- 内核 + 光晕双源：中心亮、边缘柔；squash>1 为地面透视椭圆
        local flick = layer.flicker or 0
        local flick_v = 1 + flick * math.sin(phase * 3 + (layer.phase or 0))
        local squash = layer.squash or 1.6
        local strength = layer.strength or 1.0
        local core_r = layer.core_r or (layer.r or 42) * 0.34
        px.relight(img, index, ramps, {
          { x = layer.x, y = layer.y - 2, r = core_r, squash = squash,
            strength = (layer.core_strength or 0.9) * flick_v, falloff = 2.0 },
          { x = layer.x, y = layer.y - 2, r = layer.r or 42, squash = squash,
            strength = strength * flick_v, falloff = layer.falloff or 3.2 },
        }, { shift = layer.shift or 0 })
        if layer.warm then
          px.warmPool(img, index, ramps, {
            x = layer.x, y = layer.y - 2,
            r = layer.warm_r or (loaded_core_r or 20) * 1.6,
            squash = squash,
            target = layer.warm_target or "stone_warm",
            core = layer.warm_core or (layer.warm_blend or 0.7),
            edge = layer.warm_core_edge or 0.1,
            ramps = layer.warm_ramps
              or { "shadow", "stone", "soil", "stone_warm", "iron", "moss", "foliage_dark" },
          })
        end
        if layer.flame ~= false then
          local ember = ramps["ember"]
          local fl = 3 + math.floor(2.2 + math.sin(phase * 5 + (layer.phase or 0)) * 1.8)
          for iy = 0, fl do
            local yy = layer.y - 2 - iy
            if yy >= 0 then
              local w_ = (iy <= 1) and 1 or 0
              for ix = -w_, w_ do
                local c = (iy <= 1) and ember[5] or ((iy <= 3) and ember[4] or ember[3])
                local xx = layer.x + ix
                if xx >= 0 and xx < W then img:putPixel(xx, yy, c) end
              end
            end
          end
          img:putPixel(layer.x, layer.y - 1, ramps["bone"][5])
          -- 偶发溅火星
          if math.sin(phase * 7 + (layer.phase or 0)) > 0.82 then
            local sx = layer.x + ((phase * 3) % 1 > 0.5 and 2 or -2)
            local sy = layer.y - 4 - fl
            if sx >= 0 and sx < W and sy >= 0 then
              img:putPixel(sx, sy, ember[4])
            end
          end
        end

      elseif t == "fog" then
        px.fog(img, index, ramps, {
          ramp = layer.ramp, y0 = layer.y0,
          strength = tc.fog_strength or layer.strength,
          baseLevel = layer.baseLevel, levelSpan = layer.levelSpan,
          field = layer.field,
        })

      elseif t == "rays" then
        px.rays(img, index, ramps, layer_rng(), {
          x = layer.x, y = layer.y, angle = layer.angle,
          spread = layer.spread, count = layer.count or 4,
          length = layer.length or H,
          strength = (layer.strength or 0.4)
            * (1 + (layer.flicker or 0) * math.sin(phase * 1.5)),
          ramp = layer.ramp, step = layer.step,
        })

      elseif t == "embers" then
        px.embers(img, ramps, layer_rng(), {
          count = layer.count or 20, x0 = layer.x0, x1 = layer.x1,
          y0 = layer.y0, y1 = layer.y1, phase = phase,
          ramp = layer.ramp, rise = layer.rise, index = index,
        })

      elseif t == "fg_band" then
        -- 前景剪影带：不规则顶缘的深色框景（增强纵深/叙事感）
        local ramp = ramps[layer.ramp or "shadow"]
        local base = layer.y or (H - 14)
        local amp = layer.amplitude or 6
        local brng = layer_rng()
        local tops = {}
        local cur = base
        for x = 0, W - 1 do
          cur = cur + (brng() - 0.5) * 2.2
          cur = math.max(base - amp, math.min(base + amp, cur))
          tops[x] = math.floor(cur)
        end
        for x = 0, W - 1 do
          for y = tops[x], H - 1 do
            local prob = layer.density or 0.9
            if y <= tops[x] + 1 or px.bayer(x, y) < prob then
              img:putPixel(x, y, px.rampColor(ramp, layer.level or 1))
            end
          end
        end

      else
        error("未知图层类型：" .. tostring(t))
      end
      ::continue::
    end
    return img
  end

  -- 渲染全部帧
  local images = {}
  for f = 1, frames do
    images[f] = render_frame(f)
  end

  local name = scene.name or "scene"
  local png_paths = {}
  for f = 1, frames do
    local fname = (f == 1) and (name .. ".png") or string.format("%s_f%d.png", name, f)
    local p = out .. "/" .. fname
    px.save(images[f], p)
    png_paths[f] = p
  end

  local ase_path = out .. "/" .. name .. ".aseprite"
  local sprite = Sprite(W, H, ColorMode.RGB)
  sprite.layers[1].name = name
  for f = 1, frames do
    if f > 1 then sprite:newEmptyFrame() end
    sprite:newCel(sprite.layers[1], f, images[f], Point(0, 0))
    sprite.frames[f].duration = 1.0 / fps
  end
  sprite:saveCopyAs(ase_path)

  px.emit({
    ok = true, name = name, seed = seed, frames = frames, fps = fps,
    size = { W, H },
    files = { aseprite = ase_path, png = png_paths[1], png_frames = png_paths },
  })
end

local ok, err = pcall(run)
if not ok then
  fallback_emit(err)
end
