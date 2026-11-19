--[[
  Trace: /chat trace - records how the next lines are sorted into tabs, for
  reading outside the game (SenditDB.account.chat.trace after /reload).
  Per line: Blizzard window index, type id, the chat type the id names,
  the event, the kind / channel key, and where the line went (tab indices
  or why it was dropped); the start notes every own tab's switches and
  General's hidden kinds. Diagnostic (English), read-only: never changes
  how lines flow.

  Trace.Start(n)   record the next n lines (replaces an earlier trace)
  Trace.Line(index, infoID, event, text, outcome)   called by ChatLines
  Trace.active     true while recording
]]
local _, ns = ...
local Safe = ns.Safe

local Trace = { active = false }
ns.Trace = Trace

local left = 0

local function Keys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = tostring(k) end
    table.sort(out)
    return table.concat(out, ",")
end

function Trace.Start(n)
    left = n
    Trace.active = n > 0
    local tabs = {}
    for _, t in ipairs(ns.acct.tabs or {}) do
        tabs[#tabs + 1] = ("%d %s: %s"):format(100 + t.id, tostring(t.name), Keys(t.take))
    end
    local ids = {}
    local info = _G["ChatTypeInfo"]
    for _, k in ipairs({ "SAY", "GUILD", "PARTY", "PARTY_LEADER", "MONEY", "LOOT", "COMBAT_XP_GAIN", "SYSTEM", "CHANNEL1", "CHANNEL2" }) do
        local t = type(info) == "table" and info[k]
        ids[#ids + 1] = k .. "=" .. tostring(type(t) == "table" and Safe.Num(t.id))
    end
    local walked = 0
    if type(info) == "table" then for _ in pairs(info) do walked = walked + 1 end end
    ids[#ids + 1] = "pairs=" .. walked .. " mapped=" .. tostring(ns.Mirror.ChatType(type(info) == "table" and info.GUILD and info.GUILD.id))
    ns.acct.trace = {
        started = time(),
        tabs = tabs,
        hidden = Keys(ns.acct.generalHide),
        ids = table.concat(ids, " "),
        lines = {},
    }
end

function Trace.Line(index, infoID, event, text, outcome)
    if left <= 0 then return end
    left = left - 1
    if left == 0 then Trace.active = false end
    local plain = Safe.Str(text)
    local chatType = ns.Mirror.ChatType(infoID)
    local key = ns.Tabs.KeyFor(infoID, event, text)
    local lines = ns.acct.trace.lines
    lines[#lines + 1] = ("w%s id=%s type=%s ev=%s key=%s -> %s | %s"):format(
        tostring(index), tostring(Safe.Num(infoID)), tostring(chatType), tostring(Safe.Str(event)),
        tostring(key), tostring(outcome), plain and plain:gsub("|", "!"):sub(1, 70) or "<secret>")
end
