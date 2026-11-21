--[[
  Catalog: the graphics CVars the page offers - only values the client's graphics menu cannot reach:
  a detail CVar whose menu top level already sets its best value is not listed (measured with
  /sendit graphics menu, build 70959), nor render scale / sharpness (menu sliders). Groups in page order.
  Group: { key, icon, entries }.
  Entry: { cvar, kind = "range" | "switch" | "choice", lo, hi, step, raid (a RAID<cvar> twin exists),
           best (the value "Maximum" sets; nil = left alone), choices = { values },
           menu (what the menu's top level sets), cost (from this value on it costs frame rate; for
           lower-is-better entries at and below it), src ("guide" = player guides, "estimate" = ours) }
  Ranges: "measured" = the range the engine accepts (/sendit graphics probe, build 70959; it rejects
  values outside); "engine: no limit" = any value accepted, the top is an assumption.
]]
local _, ns = ...

local HI, LO = "hi", "lo"
local MEDIA = "Interface\\AddOns\\Sendit_Graphics\\Media\\"

local function Range(cvar, lo, hi, step, raid, best, extra)
    local e = { cvar = cvar, kind = "range", lo = lo, hi = hi, step = step, raid = raid, best = best }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

local function Switch(cvar, raid, best, extra)
    local e = { cvar = cvar, kind = "switch", raid = raid, best = best }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

ns.Catalog = {
    { key = "ground", icon = MEDIA .. "Ground", entries = {
        -- measured; guides: dense grass "can significantly reduce FPS", balanced presets use 64-128
        Range("groundEffectDensity", 16, 256, 8, true, HI, { menu = 48, cost = 128, src = "guide" }),
        -- measured; guides: performance presets 140-350, the cost grows with the distance
        Range("groundEffectDist", 40, 500, 10, true, HI, { menu = 320, cost = 350, src = "guide" }),
        Range("groundEffectFade", 0, 500, 10, true, HI),      -- engine: no limit; top = assumption
    } },
    { key = "view", icon = MEDIA .. "ViewDistance", entries = {
        -- engine: no limit; guides call it the biggest cost (balanced preset 5000); above the menu's
        -- 10000 untested
        Range("farclip", 500, 20000, 100, true, HI, { menu = 10000, cost = 5000, src = "guide" }),
        Range("horizonStart", 400, 10000, 100, true, HI, { menu = 4000 }),   -- guides: minimal cost
        Range("horizonClip", 1000, 20000, 100, true, HI, { menu = 10000 }),  -- costs only with farclip
        Range("terrainLodDist", 200, 2000, 50, true, HI, { menu = 650, cost = 1000, src = "estimate" }),
        Range("wmoLodDist", 100, 2000, 50, true, HI, { menu = 400, cost = 1000, src = "estimate" }),
        Range("wmoDoodadDist", 100, 5000, 100, false, HI, { cost = 3000, src = "estimate" }),
    } },
    { key = "objects", icon = MEDIA .. "Objects", entries = {
        Range("doodadLodScale", 25, 400, 5, true, HI, { menu = 150, cost = 250, src = "estimate" }),
        -- measured
        Range("lodObjectFadeScale", 50, 5000, 50, true, HI, { menu = 150, cost = 400, src = "estimate" }),
        -- measured; smaller = more objects
        Range("lodObjectCullSize", 1, 100, 1, true, LO, { menu = 14, cost = 8, src = "estimate" }),
        Range("lodObjectMinSize", 0, 1000, 5, true, LO, { menu = 20, cost = 5, src = "estimate" }),
        Range("entityLodDist", 0, 20, 1, true, HI, { menu = 10, cost = 15, src = "estimate" }),
        Range("entityLodOffset", 0, 20, 1, false, HI, { cost = 15, src = "estimate" }),
        Switch("dynamicLod", false, 0, { cost = 0, src = "estimate" }),  -- off: no automatic detail cuts
    } },
    { key = "shadows", icon = MEDIA .. "Shadows", entries = {
        -- guides: shadows are the biggest strain; on FPS drops go back to 2048
        { cvar = "shadowTextureSize", kind = "choice", choices = { 1024, 2048, 4096 }, raid = true, best = HI,
          menu = 2048, cost = 4096, src = "guide" },
        Switch("shadowBlendCascades", true, 1),
        Range("entityShadowFadeScale", 0, 100, 5, true, HI, { menu = 50, cost = 75, src = "estimate" }),
    } },
    { key = "extras", icon = MEDIA .. "Extras", entries = {
        Range("reflectionMode", 0, 4, 1, true, HI, { menu = 3, cost = 4, src = "estimate" }),  -- measured
        Range("SkyCloudLOD", 0, 3, 1, false, HI),             -- engine: no limit; top = assumption
        Switch("ResampleAlwaysSharpen", false),               -- guides: little GPU load
    } },
}

ns.byCvar = {}
for _, group in ipairs(ns.Catalog) do
    for _, e in ipairs(group.entries) do ns.byCvar[e.cvar] = e end
end

-- the value "Maximum" sets for an entry, nil = left alone
function ns.Best(e)
    if e.best == HI then return e.kind == "choice" and e.choices[#e.choices] or e.hi end
    if e.best == LO then return e.lo end
    return e.best
end

-- true when v sits in the range that costs frame rate
function ns.Costly(e, v)
    if e.cost == nil or v == nil then return false end
    if e.best == LO or (e.kind == "switch" and e.best == 0) then return v <= e.cost end
    return v >= e.cost
end
