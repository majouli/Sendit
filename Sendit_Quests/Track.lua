--[[
  Track: where a quest happens and the race / class check - the pieces the
  right click menu (UI/Window.lua) and the chain guide (Guide.lua) share.
  Pins: Sendit's map pin (UI/MapPin.lua) at a place from Data/Places.lua
  (giver, turn-in, first objective on client maps); the map opens on it.

  Track.Allowed(id) -> bool        race / class masks of the source
  Track.Places(id) -> { g?, f?, t? } known places of a quest
  Track.Pin(id, kind) -> notice text: a pin on that place of ANY quest, done or
                         not (to show someone else the way)
]]
local _, ns = ...
local Track = {}
ns.Track = Track
local WORD = 4294967296  -- the source masks carry flags above bit 31: only the low word counts

local Read = ns.Read

local function Has(mask, index)
    if type(mask) ~= "number" or type(index) ~= "number" then return true end
    mask = mask % WORD
    if mask == 0 then return true end
    return math.floor(mask / 2 ^ (index - 1)) % 2 == 1
end

function Track.Allowed(id)
    local q = ns.quests[id]
    if not q then return true end
    local _, _, race = Read(UnitRace, "player")
    local _, _, class = Read(UnitClass, "player")
    return Has(q.requiredRaces, race) and Has(q.requiredClasses, class)
end

-- Sendit's own pin on the world map at a place of quest sid ("g" giver,
-- "f" turn-in, "t" objective); the map opens there.
local function Pin(sid, kind)
    local spots = ns.places and ns.places[sid]
    local s = spots and spots[kind]
    if not s then return false end
    ns.MapPin.Set(s[1], s[2], s[3], sid, kind)
    ns.MapPin.Show()
    return true
end

function Track.Places(id) return ns.places and ns.places[id] or {} end

function Track.Pin(id, kind)
    local L, name = ns.L, ns.Database.Name(id)
    if not Pin(id, kind) then return L.trackNoPlace:format(name) end
    return (kind == "g" and L.trackGiver or kind == "f" and L.trackTurnIn or L.trackTarget):format(name)
end
