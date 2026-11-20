--[[
  Censored: Blizzard's hidden "potentially inappropriate" messages, shown in place on the player's click.
  Blizzard's own handler would rewrite its chat frames tainted (SetItemRef from addon code), so we take
  the click: C_ChatInfo.UncensorChatLine + GetChatLineText, replaced in the messenger and the tabs.
  Censored.Show(lineID) -> found;  Censored.Marker(lineID)
]]
local _, ns = ...
local Safe = ns.Safe

local Censored = {}
ns.Censored = Censored

function Censored.Marker(lineID) return "censoredmessage:" .. lineID .. "|h" end

function Censored.Show(lineID)
    lineID = tonumber(lineID)
    local api = _G["C_ChatInfo"]
    if not (lineID and api and api.GetChatLineText) then return false end
    if api.UncensorChatLine then pcall(api.UncensorChatLine, lineID) end
    local ok, raw = pcall(api.GetChatLineText, lineID)
    local text = ok and Safe.Str(raw) or nil
    if not text or text == "" then return false end
    local marker = Censored.Marker(lineID)
    local found = false
    if ns.Whispers and ns.Whispers.Uncensor(marker, text) then found = true end
    if ns.ChatLines and ns.ChatLines.Uncensor(marker, text) then found = true end
    return found
end
