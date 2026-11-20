--[[
  Mentions: your first name in group / guild / public chat turns gold, the tab gets a dot, a soft sound
  plays (at most every PING_GAP s).  Mentions.Apply(text) -> text, mentioned
]]
local _, ns = ...
local Safe, Links = ns.Safe, ns.Links

local Mentions = {}
ns.Mentions = Mentions

local PING_GAP = 2
local lastPing = 0

local function MyName()
    local name = Safe.Str(Safe.Call(_G["UnitName"], "player"))
    return name and name:match("^(%S+)")
end

local function Ping()
    local now = GetTime()
    if now - lastPing < PING_GAP then return end
    lastPing = now
    local kit = _G["SOUNDKIT"]
    local id = kit and (kit.TELL_MESSAGE or kit.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if id then pcall(PlaySound, id) end
end

function Mentions.Apply(text)
    if not ns.db.mentions then return text, false end
    local shown, mentioned = Links.Mention(text, MyName())
    if mentioned then Ping() end
    return shown, mentioned
end
