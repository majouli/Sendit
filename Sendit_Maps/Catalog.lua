--[[
  Catalog: the instances with a map.
  Catalog.List() -> { { id, name, raid, min } } dungeons first, then raids, each by level
  Catalog.Here() -> the instance map ID the player is in (dungeon or raid) | nil
  Catalog.Name(id) -> the instance's name in the suite language (else the client's)
  Catalog.Has(id) -> the instance has a map (room tiles or the client's drawn art)
]]
local _, ns = ...
local Catalog = {}
ns.Catalog = Catalog

local function Info(id)
    local svc = Sendit.Service("dungeons")
    return svc and svc.Map and svc.Map(id) or nil
end

function Catalog.Name(id)
    local info = Info(id)
    if info and info.name then return info.name end
    local name = GetRealZoneText and GetRealZoneText(id)
    return (type(name) == "string" and name ~= "") and name or ("#" .. id)
end

-- the map style chosen (profile mapStyle): "drawn" (the rooms in the drawn look) | "blizzard" (the client's
-- drawn maps) | "rooms"; an instance without that kind of map shows the other
function Catalog.Style()
    local s = ns.module.profile and ns.module.profile.mapStyle
    if s == "art" then return "drawn" end  -- an older saved default
    return (s == "blizzard" or s == "rooms") and s or "drawn"
end

-- how an instance is drawn: "art" (the client's map) or "rooms" with canvas style "drawn" | "rooms"
function Catalog.Look(id)
    local style, tiles, art = Catalog.Style(), ns.maps[id] ~= nil, ns.Art.Has(id)
    if (style == "blizzard" and art) or not tiles then return "art" end
    return "rooms", style == "rooms" and "rooms" or "drawn"
end

function Catalog.Has(id) return id ~= nil and (ns.maps[id] ~= nil or ns.Art.Has(id)) end

function Catalog.List()
    local out, ids = {}, {}
    for id in pairs(ns.maps) do ids[id] = ns.maps[id] end
    for id in pairs(ns.art or {}) do ids[id] = ids[id] or {} end
    for id, map in pairs(ids) do
        local info = Info(id)
        out[#out + 1] = { id = id, name = Catalog.Name(id), raid = (info and info.raid) or map.raid == true,
            min = info and info.min or 0 }
    end
    table.sort(out, function(a, b)
        if a.raid ~= b.raid then return not a.raid end
        if a.min ~= b.min then return a.min < b.min end
        return a.name < b.name
    end)
    return out
end

function Catalog.Here()
    local _, kind, _, _, _, _, _, id = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return nil end
    return id
end
