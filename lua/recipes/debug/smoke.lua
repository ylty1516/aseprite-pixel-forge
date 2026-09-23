-- 最小示例配方（doctor 冒烟 / 测试 / 配方写作模板）
-- 画一颗带明暗、轮廓和苔藓点的球体。
local function generate(ctx)
  local px = ctx.px
  local w, h = ctx.size[1], ctx.size[2]
  local r = math.min(ctx.params.radius, math.min(w, h) / 2 - 2)

  local m = px.canvas(w, h)
  px.blob(m, ctx.rng, w / 2, h / 2, r, {irregularity = 0.25, points = 10, smooth = 1})

  local img = px.newImage(w, h)
  local stone = px.rampOf(ctx.style, "stone")
  px.paintShaded(img, m, stone, {
    light = ctx.style.lighting, rng = ctx.rng, jitter = true, jitterChance = 0.35,
  })
  px.clusterJitter(img, m, stone, ctx.rng, {chance = 0.2})
  if ctx.params.mossy then
    px.speckle(img, m, px.rampOf(ctx.style, "moss"), ctx.rng,
      {count = math.floor(r), size = 1, levels = {2, 3}})
  end
  px.outline(img, m, ctx.style.outline.color, {
    policy = ctx.style.outline.policy, light = ctx.style.lighting, rng = ctx.rng,
  })
  return {img = img, mask = m}
end

return {
  name = "smoke",
  category = "debug",
  size = {16, 16},
  params = {
    radius = {type = "float", min = 3, max = 6, default = 5},
    mossy = {type = "bool", default = true},
  },
  generate = generate,
}
