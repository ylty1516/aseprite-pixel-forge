-- gen.lua — aseprite-pixel-forge 生成入口
-- 模式：
--   describe: 输出配方参数规格（JSON 到 stdout 的 FORGE: 行）
--   generate: 按参数生成候选图（.png + .aseprite）
-- 注意：所有 --script-param 必须由调用方放在 --script 之前（Aseprite CLI 要求）。
-- 整个流程包在 pcall 中：任何错误都以 FORGE:{"ok":false,...} 输出而不崩溃。

local function fallback_emit(msg)
  local s = tostring(msg):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
  print('FORGE:{"ok":false,"error":"' .. s .. '"}')
end

local function run()
  local P = app.params or {}

  local function need(key)
    local v = P[key]
    if v == nil or v == "" then
      error("缺少 --script-param " .. key, 2)
    end
    return v
  end

  local px = dofile(need("lib"))
  local style = dofile(need("style"))
  local recipe = dofile(need("recipe"))
  local mode = P["mode"] or "generate"

  local function parse_size(text)
    if not text then return nil, nil end
    local w, h = tostring(text):match("^(%d+)x(%d+)$")
    if w then return tonumber(w), tonumber(h) end
    return nil, nil
  end

  if mode == "describe" then
    local w, h = parse_size(P["size"])
    if not w then
      if recipe.size then
        w, h = recipe.size[1], recipe.size[2]
      else
        w, h = style.default_size, style.default_size
      end
    end
    px.emit({
      ok = true,
      describe = {
        name = recipe.name,
        category = recipe.category or "misc",
        size = { w, h },
        params = recipe.params or {},
      },
    })
    return
  end

  -- ---------------- generate ----------------
  local seed = px.tonum(P["seed"], 1)
  local name = P["name"] or "candidate"
  local outdir = P["out"] or "."
  local w, h = parse_size(P["size"])
  if not w then
    if recipe.size then
      w, h = recipe.size[1], recipe.size[2]
    else
      w, h = style.default_size, style.default_size
    end
  end

  local overrides = px.parseKV(P["params"])
  local merged = {}
  for key, spec in pairs(recipe.params or {}) do
    local v = overrides[key]
    if v ~= nil then
      local t = spec.type
      if t == "int" or t == "float" then
        merged[key] = px.tonum(v, spec.default)
      elseif t == "bool" then
        merged[key] = px.tobool(v, spec.default)
      else
        merged[key] = v
      end
    else
      merged[key] = spec.default
    end
  end

  -- 多帧动画：每帧用同一 seed 重建基础形态，再用 ctx.phase 叠加帧间差异
  local frames = math.floor(px.tonum(P["frames"] or merged.frames or 1, 1))
  frames = math.max(1, math.min(8, frames))
  local fps = px.tonum(P["fps"] or merged.fps or 8, 8)
  if fps <= 0 then fps = 8 end

  local images = {}
  for f = 1, frames do
    local rng = px.rng(seed)
    local ctx = {
      style = style, params = merged, rng = rng, seed = seed,
      size = { w, h }, px = px,
      frame = f, frames = frames,
      phase = (f - 1) / frames * math.pi * 2,
    }
    local out = recipe.generate(ctx)
    images[f] = out.img or out
  end

  local png_paths = {}
  for f = 1, frames do
    local fname = (f == 1) and (name .. ".png")
      or string.format("%s_f%d.png", name, f)
    local p = outdir .. "/" .. fname
    px.save(images[f], p)
    png_paths[f] = p
  end

  local ase_path = outdir .. "/" .. name .. ".aseprite"
  local sprite = Sprite(w, h, ColorMode.RGB)
  sprite.layers[1].name = recipe.name or "art"
  for f = 1, frames do
    if f > 1 then sprite:newEmptyFrame() end
    sprite:newCel(sprite.layers[1], f, images[f], Point(0, 0))
    sprite.frames[f].duration = 1.0 / fps
  end
  sprite:saveCopyAs(ase_path)

  px.emit({
    ok = true, name = name, seed = seed,
    frames = frames, fps = fps,
    files = {
      aseprite = ase_path,
      png = png_paths[1],
      png_frames = png_paths,
    },
    params = merged,
  })
end

local ok, err = pcall(run)
if not ok then
  fallback_emit(err)
end
