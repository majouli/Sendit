--[[
  Censored: Blizzard's hidden "potentially inappropriate" messages, shown
  in place where the player clicks them.

  The client hides such a line itself: the chat event's text already is
  Blizzard's notice (CENSORED_MESSAGE_HIDDEN) with a
  "|Hcensoredmessage:<lineID>|h[Show Message]|h" link. Blizzard's own link
  handler uncensors the line and rewrites its chat frames in place
  (TransformMessages) - run from addon code (SetItemRef) that would write
  Blizzard's chat frames tainted, and Sendit's windows hold their own copy
  anyway. So Sendit takes the click itself: C_ChatInfo.UncensorChatLine,
  then the original text from C_ChatInfo.GetChatLineText, and replaces the
  notice in the messenger (Whispers.Uncensor) and the chat tabs
  (ChatLines.Uncensor). The click stays the player's own decision; nothing
  is shown without it.

  Censored.Show(lineID) -> true when the text was found and replaced
  Censored.Marker(lineID) the link part a notice holds ("censoredmessage:<id>|h")
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
