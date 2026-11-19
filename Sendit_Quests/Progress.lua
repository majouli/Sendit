--[[
  Progress: current-character completion/log membership, guarded against
  missing APIs and secret return values. "Not completed" is never called
  "available": the reference does not evaluate race/reputation/item gates.
  The completion snapshot and per-ID state cache expire on quest events;
  confirmed turn-ins fill the gap before the client snapshot catches up.
]]
local _, ns = ...
local P = {}
ns.Progress = P
local completed, snapshot
local sessionCompleted = {}
local states = {}
local logSnapshot

local Read = ns.Read

function P.Invalidate()
    completed, snapshot = nil, nil
    wipe(states)
    logSnapshot = nil
end

local function Completed()
    if completed then return completed end
    completed = {}
    local ids = Read(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
    snapshot = type(ids) == "table"
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            if not (issecretvalue and issecretvalue(id)) and type(id) == "number" then completed[id] = true end
        end
    end
    return completed
end

function P.State(id)
    if states[id] then return states[id] end
    local api = C_QuestLog or {}
    if P.Log()[id] then states[id] = "active" return "active" end
    if sessionCompleted[id] or Completed()[id] then states[id] = "done" return "done" end
    local done = Read(api.IsQuestFlaggedCompleted, id)
    if done then states[id] = "done" return "done" end
    local active = Read(api.IsOnQuest, id)
    if active then states[id] = "active" return "active" end
    states[id] = (done == false or snapshot) and active == false and "pending" or "unknown"
    return states[id]
end

function P.Role(state)
    return state == "done" and "success" or state == "active" and "warning"
        or state == "unknown" and "textMuted" or "textDim"
end

function P.Summary(rows)
    local counts = { done = 0, active = 0, pending = 0, unknown = 0 }
    for _, row in ipairs(rows) do
        local state = P.State(row.id)
        counts[state] = counts[state] + 1
    end
    return counts
end

function P.Selected()
    local id = Read(C_QuestLog and C_QuestLog.GetSelectedQuest)
    return type(id) == "number" and id > 0 and id or nil
end

function P.Log()
    if logSnapshot then return logSnapshot end
    local api, out = C_QuestLog or {}, {}
    logSnapshot = out
    local count = Read(api.GetNumQuestLogEntries)
    if type(count) ~= "number" then return out end
    for i = 1, count do
        local info = Read(api.GetInfo, i)
        if type(info) == "table" then
            local id, title = info.questID, info.title
            if not (issecretvalue and (issecretvalue(id) or issecretvalue(title)))
                and type(id) == "number" and id > 0 then out[id] = type(title) == "string" and title or ("#" .. id) end
        end
    end
    return out
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, id)
    if event == "QUEST_TURNED_IN" and not (issecretvalue and issecretvalue(id)) and type(id) == "number" then
        sessionCompleted[id] = true
    end
    P.Invalidate()
    if ns.Window then ns.Window:UpdateProgress() end
end)
