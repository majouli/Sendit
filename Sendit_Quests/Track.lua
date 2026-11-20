--[[
  Track: a quest's places and the race / class check, shared by the menu and the guide.
  Track.Allowed(id) -> bool;  Track.Places(id) -> { g?, f?, t? }
  Track.Pin(id, kind) -> notice text: our map pin on that place of any quest (done ones too)
]]
local _, ns = ...
local Track = {}
ns.Track = Track
local WORD = 4294967296  -- the masks carry flags above bit 31: only the low word counts

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
