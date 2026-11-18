--[[
  Track: right click on a quest = continue its chain. Finds the furthest
  station the character can work on now and points the game at it:
    - a quest of the chain in the quest log: watched and super-tracked, and a
      map pin on where to go - its turn-in when complete, else its objective
      NPC / object (only when the data knows it)
    - else the next step whose known prerequisites are done: a map pin on
      its quest giver
  Pins: Sendit's own marker on the world map (UI/MapPin.lua) at the place
  from Data/Places.lua (QuestieDB spawns on client maps); the map opens on it.
  Steps another race or class cannot take (source requiredRaces /
  requiredClasses masks) are skipped. Nothing reachable: the chain is done,
  or no station is known - said so in the window, never in chat.

  Track.Allowed(id) -> bool        race / class masks of the source
  Track.Station(id) -> stationID, how ("log" | "giver") or nil, reason
  Track.Go(id) -> text for the window's notice
]]
local _, ns = ...
local Track = {}
ns.Track = Track
local WORD = 4294967296  -- the source masks carry flags above bit 31: only the low word counts

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue and (issecretvalue(a) or issecretvalue(b) or issecretvalue(c)) then return nil end
    return a, b, c
end

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

function Track.Station(id)
    local rows = ns.Database.Chain(id)
    local logged, nextStep
    for _, row in ipairs(rows) do
        local sid = row.id
        if Track.Allowed(sid) then
            local state = ns.Style.Show(sid, ns.Database.Prerequisites(sid))
            if state == "active" then logged = sid
            elseif state == "next" then nextStep = sid end
        end
    end
    if logged then return logged, "log" end
    if nextStep then return nextStep, "giver" end
    local counts = ns.Progress.Summary(rows)
    return nil, counts.done == #rows and "done" or "none"
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

-- A quest in the log: watched; the pin goes to its turn-in when it is
-- complete, else to its objective (when the data knows where that is).
local function InLog(sid, L, name)
    local api = C_QuestLog or {}
    if api.AddQuestWatch then pcall(api.AddQuestWatch, sid) end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then pcall(C_SuperTrack.SetSuperTrackedQuestID, sid) end
    if Read(api.IsComplete, sid) == true then
        if Pin(sid, "f") then return L.trackTurnIn:format(name(sid)) end
    elseif Pin(sid, "t") then
        return L.trackTarget:format(name(sid))
    end
    return L.trackLog:format(name(sid))
end

function Track.Go(id)
    local L, name = ns.L, ns.Database.Name
    local sid, how = Track.Station(id)
    if not sid then return how == "done" and L.trackDone or L.trackNone end
    if how == "log" then return InLog(sid, L, name) end
    if Pin(sid, "g") then return L.trackGiver:format(name(sid)) end
    return L.trackNoPin:format(name(sid))
end
