--[[
  ChatLines: the line flow into Sendit Chat's tabs.

  Blizzard's mirrored line (Core/Mirror.lua) -> loot style, short channels,
  spell links, mentions, links -> the tab (own tabs may take it out of
  General, Core/Tabs.lua) -> remembered (Core/History.lua) -> unread dot
  (Windows.Arrived). Combat log lines are shown as they come: not kept, no
  unread dot, and they follow Blizzard's refilter (clear + backfill).
  On login the earlier session's lines come first, under an "earlier
  session" line; then Mirror hands over what arrived since.

  ChatLines.OnLine(index, text, r, g, b, whisper, event, infoID)  Mirror's sink
  ChatLines.Copy(index)      a tab's text in the copy box (UI/CopyBox.lua)
  ChatLines.Replay()         the earlier session (tests)
  ChatLines.CombatReset(kind, text, r, g, b)  Mirror's combat log reset
]]
local _, ns = ...
local Safe, Links, Mirror, History, Mentions, Tabs = ns.Safe, ns.Links, ns.Mirror, ns.History, ns.Mentions, ns.Tabs
local L = ns.L

local ChatLines = {}
ns.ChatLines = ChatLines

local function SMF(index) return ns.Windows._SMF(index) end

function ChatLines.Replay()
    for index, lines in History.Saved() do
        if #lines > 0 then
            local smf = SMF(index)
            for _, l in ipairs(lines) do smf:AddMessage(l[1], l[2], l[3], l[4]) end
            smf:AddMessage("|cff8a8f9c——  " .. L.EARLIER .. "  ——|r")
        end
    end
end

local function Show(index, text, r, g, b)
    SMF(index):AddMessage(text, r, g, b)
    History.Remember(index, text, r, g, b)
    ns.Windows.Arrived(index)
end

function ChatLines.OnLine(index, text, r, g, b, whisper, event, infoID)
    if Mirror.IsCombatLog(index) then
        SMF(index):AddMessage(text, r, g, b)
        ns.Windows.Arrived(index, true)
        return
    end
    if whisper and ns.db.splitWhispers and not Safe.IsSecret(text) then return end
    local shown = ns.Loot.Style(text, event)
    if shown == false then return end  -- summed up elsewhere (loot rolls)
    if ns.db.shortChannels then shown = Links.ShortChannels(shown) end
    shown = Links.Decorate((Mentions.Apply(ns.SpellLinks.Restore(shown))))
    local targets = Tabs.Route(index, infoID)
    if not targets then
        Show(index, shown, r, g, b)
        return
    end
    for _, i in ipairs(targets) do Show(i, shown, r, g, b) end
end

-- Blizzard refilters its combat log: Clear, then oldest-first BackFillMessage.
function ChatLines.CombatReset(kind, text, r, g, b)
    for _, index in ipairs(Tabs.All()) do
        if Mirror.IsCombatLog(index) then
            local smf = SMF(index)
            if kind == "clear" then
                smf:Clear()
            elseif smf.BackFillMessage then
                smf:BackFillMessage(text, r, g, b)
            end
        end
    end
end

-- The combat log keeps no history: its lines come from the message frame
-- (secret ones skipped).
function ChatLines.Copy(index)
    if not Mirror.IsCombatLog(index) then
        ns.CopyBox.Show(History.Lines(index))
        return
    end
    local smf, lines = SMF(index), {}
    local n = Safe.Num(Safe.Call(smf.GetNumMessages, smf)) or 0
    for k = 1, n do
        local text = Safe.Str(Safe.Call(smf.GetMessageInfo, smf, k))
        if text then lines[#lines + 1] = { text } end
    end
    ns.CopyBox.Show(lines)
end

ns.OnReady(function()
    ChatLines.Replay()  -- earlier session first (windows exist: UI/ChatWindow.lua ran first)
    Mirror.SetSink(ChatLines.OnLine)
    Mirror.SetCombatReset(ChatLines.CombatReset)
end)
