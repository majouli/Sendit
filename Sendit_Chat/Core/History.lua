--[[
  History: every tab's lines as plain data, for the copy box; with keepHistory saved per character
  (Sendit_ChatCharDB.history) and replayed after /reload. Secret lines (lockdown) are skipped.
  History.Remember(index, text, r, g, b) / Lines(index) / Saved() / Sync()
]]
local _, ns = ...
local Safe = ns.Safe

local History = {}
ns.History = History

local MAX = 200
local session = {}  -- [index] = lines while keepHistory is off

local function Store()
    return ns.db.keepHistory and ns.char.history or session
end

function History.Lines(index)
    local store = Store()
    store[index] = store[index] or {}
    return store[index]
end

function History.Remember(index, text, r, g, b)
    if not Safe.Str(text) then return end
    local lines = History.Lines(index)
    lines[#lines + 1] = { text, Safe.Num(r), Safe.Num(g), Safe.Num(b) }
    while #lines > MAX do table.remove(lines, 1) end
end

function History.Saved()
    return pairs(ns.db.keepHistory and ns.char.history or {})
end

function History.Sync()
    if not ns.db.keepHistory then wipe(ns.char.history) end
end
