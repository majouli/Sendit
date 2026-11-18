local _, ns = ...
local L = ns.L

local Sk = {}
ns.Skinning = Sk

local Plain = ns.Plain

function Sk.RequiredSkill(level)
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end

function Sk.NpcID(guid)
    if not Plain(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

function Sk.ForNpc(npcID, level, isBeast)
    local lid = npcID and ns.SkinNpc[npcID]
    if lid then return ns.Loot.Expand(ns.SkinLoot[lid]), { source = "npc" } end
    if npcID and npcID <= ns.SkinClassicMaxNpc then return nil end
    if not isBeast or not level or not ns.SkinLevel[level] then return nil end
    return ns.Loot.Expand(ns.SkinLevel[level]), { source = "level", level = level }
end

function Sk.NpcByName(unit, title)
    local name = UnitName(unit)
    if not Plain(name) or name == "" then name = title end
    if not Plain(name) or name == "" then return nil end
    return ns.SkinNpcByName[name]
end

function Sk.ForUnit(unit, guid, title)
    if not Plain(guid) then guid = UnitGUID(unit) end
    local npcID = Sk.NpcID(guid) or Sk.NpcByName(unit, title)
    if not npcID then return nil end
    local raw = UnitLevel(unit)
    local level = (Plain(raw) and raw > 0) and raw or nil
    local ctype = UnitCreatureType(unit)
    local isBeast = Plain(ctype) and ns.ClientNames.beasts[ctype] == true
    local results, info = Sk.ForNpc(npcID, level, isBeast)
    if results and level then info.skill = Sk.RequiredSkill(level) end
    return results, info
end

function Sk.ProbeLines()
    local unit = UnitExists("target") and "target" or (UnitExists("mouseover") and "mouseover")
    if not unit then return { L.probeNoUnit } end
    local function show(v)
        if v == nil then return "-" end
        if not Plain(v) then return L.secret end
        return tostring(v)
    end
    local guid, level, ctype = UnitGUID(unit), UnitLevel(unit), UnitCreatureType(unit)
    local results, info = Sk.ForUnit(unit, guid)
    local data = L.none
    if results and info then data = info.source == "npc" and L.probeNpcData or L.probeLevelData end
    return {
        L.probeUnit:format(unit, show(Sk.NpcID(guid)), show(level), show(ctype), data),
        L.probeIds:format(show((UnitName(unit))), show(Sk.NpcByName(unit)), show(guid)),
    }
end
