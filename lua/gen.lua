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

  local rng = px.rng(seed)
  local ctx = {
    style = style, params = merged, rng = rng, seed = seed,
    size = { w, h }, px = px,
  }
  local out = recipe.generate(ctx)
  local img = out.img or out

  local png_path = outdir .. "/" .. name .. ".png"
  local ase_path = outdir .. "/" .. name .. ".aseprite"
  px.save(img, png_path)

  local sprite = Sprite(w, h, ColorMode.RGB)
  sprite.layers[1].name = recipe.name or "art"
  sprite:newCel(sprite.layers[1], 1, img, Point(0, 0))
  sprite:saveCopyAs(ase_path)

  px.emit({
    ok = true, name = name, seed = seed,
    files = { aseprite = ase_path, png = png_path },
    params = merged,
  })
end

local ok, err = pcall(run)
if not ok then
  fallback_emit(err)
end
