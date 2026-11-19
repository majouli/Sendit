--[[
  Guide: "follow the chain" - every step the data knows, in chain order, as a
  list like a leveling guide: pick up, objective, turn in. Where one place
  ends a quest and starts the next (same spot), that is one step. Left out:
  done quests, steps another race / class cannot take (Track.Allowed),
  quests locked by a done alternative (exclusiveTo), an objective step whose
  place the data does not know.

  With Shortest Path Forever (optional, its public API
  ShortestPathForever.API.NavigateRoute): the steps with a known place go to
  it as one itinerary - pick-up stops carry questID, turn-ins handins - and
  it plans the way (flight points, boats, portals). Taking, finishing or
  turning in a quest changes the steps: the new itinerary goes to it again
  (only when it differs - the same owner's resubmission keeps its journey).
  Without it: Sendit's map pin on the first step; quest events move it on.

  Guide.Steps(id) -> { { place = { UiMapID, x, y } | nil, title,
                          actions = { { kind = "g"|"t"|"f", quest = id }, ... } }, ... }
  Guide.Start(id) -> notice text      Guide.Stop()
  Guide.Following() -> the followed chain's quest ID or nil
  Guide.UsesSPF() -> true while Shortest Path Forever leads the way
]]
local _, ns = ...
local Guide = {}
ns.Guide = Guide

local OWNER = "Sendit Quests"
local MAX_STOPS = 64  -- Shortest Path Forever's limit per itinerary
local following, viaSPF, sent

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil end
    return value
end

local function Done(id) return ns.Progress.State(id) == "done" end

local function Excluded(id)
    local q = ns.quests[id]
    for _, other in ipairs(q and q.exclusiveTo or {}) do
        if Done(other) then return true end
    end
    return false
end

local function Complete(id)
    local api = C_QuestLog
    return api ~= nil and Read(api.IsComplete, id) == true
end

local function Same(a, b)
    return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local VERB = { g = "stepPickUp", t = "stepObjective", f = "stepTurnIn" }

local function Title(step)
    local parts = {}
    for _, a in ipairs(step.actions) do
        parts[#parts + 1] = ns.L[VERB[a.kind]]:format(ns.Database.Name(a.quest))
    end
    return table.concat(parts, " · ")
end

function Guide.Steps(id)
    local steps = {}
    local function Add(kind, quest)
        local spot = ns.Track.Places(quest)[kind]
        if kind == "t" and not spot then return end
        local last = steps[#steps]
        if last and spot and Same(last.place, spot) then
            last.actions[#last.actions + 1] = { kind = kind, quest = quest }
        else
            steps[#steps + 1] = { place = spot, actions = { { kind = kind, quest = quest } } }
        end
    end
    for _, row in ipairs(ns.Database.Chain(id)) do
        local sid = row.id
        if not Done(sid) and ns.Track.Allowed(sid) and not Excluded(sid) then
            if ns.Progress.State(sid) ~= "active" then Add("g", sid) end
            if not Complete(sid) then Add("t", sid) end
            Add("f", sid)
        end
    end
    for _, step in ipairs(steps) do step.title = Title(step) end
    return steps
end

local function SPF()
    local spf = _G["ShortestPathForever"]
    local api = type(spf) == "table" and spf.API
    return type(api) == "table" and type(api.NavigateRoute) == "function" and api or nil
end

-- What an itinerary is, to tell a changed one from the same one.
local function Signature(stops)
    local parts = {}
    for _, s in ipairs(stops) do
        parts[#parts + 1] = table.concat({ s.map, s.x, s.y, s.questID or 0, table.concat(s.handins or {}, "+") }, ":")
    end
    return table.concat(parts, "|")
end

local function Stops(steps)
    local stops = {}
    for _, step in ipairs(steps) do
        if step.place and #stops < MAX_STOPS then
            local stop = { map = step.place[1], x = step.place[2], y = step.place[3], title = step.title }
            for _, a in ipairs(step.actions) do
                if a.kind == "g" and not stop.questID then stop.questID = a.quest end
                if a.kind == "f" then
                    stop.handins = stop.handins or {}
                    stop.handins[#stop.handins + 1] = a.quest
                end
            end
            stops[#stops + 1] = stop
        end
    end
    return stops
end

-- Sendit's own guidance: the pin on the first step that has a place; the map opens
-- only when the player asked (Start), never when quest events move the pin on.
local function PinFirst(steps, open)
    for _, step in ipairs(steps) do
        if step.place then
            local a = step.actions[1]
            ns.MapPin.Set(step.place[1], step.place[2], step.place[3], a.quest, a.kind)
            if open then ns.MapPin.Show() end
            return true
        end
    end
    return false
end

function Guide.Start(id)
    local L = ns.L
    local steps = Guide.Steps(id)
    following, viaSPF = nil, false
    if #steps == 0 then return L.trackDone end
    following = id
    local api = SPF()
    if api then
        local stops = Stops(steps)
        if #stops > 0 then
            local ok, started = pcall(api.NavigateRoute, OWNER, stops)
            if ok and started then
                viaSPF, sent = true, Signature(stops)
                return L.guideSPF:format(#stops)
            end
        end
    end
    if PinFirst(steps, true) then return L.guideOwn:format(#steps) end
    return L.guideNoPlace
end

function Guide.Stop()
    if viaSPF then
        local api = SPF()
        if api and type(api.Cancel) == "function" then pcall(api.Cancel, OWNER) end
    end
    following, viaSPF, sent = nil, false, nil
    ns.MapPin.Clear()
end

function Guide.Following() return following end
function Guide.UsesSPF() return viaSPF == true end

-- Without Shortest Path Forever our pin moves on as quests are taken, done and turned in.
local events = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function()
    if not following then return end
    ns.Progress.Invalidate()
    local steps = Guide.Steps(following)
    if viaSPF then
        local api, stops = SPF(), Stops(steps)
        if #stops == 0 then
            Guide.Stop()
        elseif api and Signature(stops) ~= sent then
            local ok, started = pcall(api.NavigateRoute, OWNER, stops)
            if ok and started then sent = Signature(stops) end
        end
        if ns.LogRoute then ns.LogRoute.Refresh() end
        return
    end
    if #steps == 0 then
        following = nil
        ns.MapPin.Clear()
        return
    end
    local first = steps[1]
    local target = ns.MapPin.Get()
    if first.place and not (target and target.map == first.place[1] and target.x == first.place[2]
        and target.y == first.place[3]) then
        PinFirst(steps)
    end
end)
