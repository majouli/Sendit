--[[
  Recorder: writes down what the game client shows of a quest, so the data
  grows with every quest you see - and the next build ships it for everyone
  (tools/gen_quests.py reads it from the SavedVariables).

  When a quest giver offers a quest (QUEST_DETAIL) and when you turn one in
  (QUEST_COMPLETE): the reward items (guaranteed and pick-one, with amounts),
  XP and money (with your level - both scale with it), the NPC / object you
  talk to and where you stand (map, x, y - next to them), the quest's title.
  Only plain values are kept: a secret or missing value is left out.

  Recorded rewards and places are used at once: rewards replace the bundled
  ones (they are what the server sent), places fill the bundled gaps.

  SavedVariables SenditQuestsSeen (account) = { version = 1, quests = {
    [questID] = { title, level, items = { { itemId, amount } }, choice = {...},
                  xp, money, giver = { kind, id, map, x, y }, turnIn = {...}, seen } } }
  Recorder.Record(kind)   "offer" | "complete" (the events call it; tests too)
  Recorder.Apply()        recorded rewards / places into ns.quests / ns.places
]]
local _, ns = ...
local Recorder = {}
ns.Recorder = Recorder

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f
end

local function Store()
    SenditQuestsSeen = type(SenditQuestsSeen) == "table" and SenditQuestsSeen or {}
    SenditQuestsSeen.version = SenditQuestsSeen.version or 1
    SenditQuestsSeen.quests = SenditQuestsSeen.quests or {}
    return SenditQuestsSeen.quests
end

local function Items(kind, count)
    local out = {}
    for i = 1, count do
        local _, _, amount, _, _, itemID = Call(GetQuestItemInfo, kind, i)
        if not (Plain(itemID) and type(itemID) == "number" and itemID > 0) then return nil end
        out[#out + 1] = { itemId = itemID, amount = Plain(amount) and type(amount) == "number" and amount or 1 }
    end
    return out
end

-- Who you talk to: "Creature-0-...-<id>-..." / "GameObject-0-...-<id>-...".
local function Partner()
    local guid = Call(UnitGUID, "npc")
    if not (Plain(guid) and type(guid) == "string") then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return "npc", tonumber(id) end
    if kind == "GameObject" then return "object", tonumber(id) end
    return nil
end

local function Here()
    local api = C_Map
    if not (api and api.GetBestMapForUnit and api.GetPlayerMapPosition) then return nil end
    local map = Call(api.GetBestMapForUnit, "player")
    if not (Plain(map) and type(map) == "number") then return nil end
    local pos = Call(api.GetPlayerMapPosition, map, "player")
    if not pos then return nil end
    local x, y = Call(pos.GetXY, pos)
    if not (Plain(x) and Plain(y) and type(x) == "number" and type(y) == "number") or (x == 0 and y == 0) then
        return nil
    end
    return map, math.floor(x * 10000 + 0.5) / 10000, math.floor(y * 10000 + 0.5) / 10000
end

function Recorder.Record(kind)
    local id = Call(GetQuestID)
    if not (Plain(id) and type(id) == "number" and id > 0) then return false end
    local rec = Store()[id] or {}
    local title = Call(GetTitleText)
    if Plain(title) and type(title) == "string" and title ~= "" then rec.title = title end
    local level = Call(UnitLevel, "player")
    if Plain(level) and type(level) == "number" then rec.level = level end
    local fixed, choices = Call(GetNumQuestRewards), Call(GetNumQuestChoices)
    if Plain(fixed) and Plain(choices) and type(fixed) == "number" and type(choices) == "number" then
        local items, choice = Items("reward", fixed), Items("choice", choices)
        if items and choice then rec.items, rec.choice = items, choice end
    end
    local xp, money = Call(GetRewardXP), Call(GetRewardMoney)
    if Plain(xp) and type(xp) == "number" then rec.xp = xp end
    if Plain(money) and type(money) == "number" then rec.money = money end
    local partner, partnerID = Partner()
    local map, x, y = Here()
    if partner or map then
        rec[kind == "offer" and "giver" or "turnIn"] = { kind = partner, id = partnerID, map = map, x = x, y = y }
    end
    rec.seen = Call(time)
    Store()[id] = rec
    Recorder.Apply(id)
    return true
end

-- What was seen goes into the data in memory: rewards replace, places fill gaps.
function Recorder.Apply(only)
    local quests = Store()
    for id, rec in pairs(quests) do
        if not only or id == only then
            local q = ns.quests[id]
            if q and rec.items and rec.choice then
                q.rewards = q.rewards or {}
                q.rewards.items, q.rewards.choice = rec.items, rec.choice
            end
            ns.places = ns.places or {}
            for key, field in pairs({ g = "giver", f = "turnIn" }) do
                local spot = rec[field]
                if spot and spot.map and spot.x then
                    ns.places[id] = ns.places[id] or {}
                    ns.places[id][key] = ns.places[id][key] or { spot.map, spot.x, spot.y }
                end
            end
        end
    end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "QUEST_DETAIL", "QUEST_COMPLETE" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "Sendit_Quests" then Store() Recorder.Apply() end
    elseif event == "QUEST_DETAIL" then
        Recorder.Record("offer")
    else
        Recorder.Record("complete")
    end
end)
