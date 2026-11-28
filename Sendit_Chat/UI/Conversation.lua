--[[
  Conversation: the messenger's right pane - header (avatar, name, realm or Battle.net; right click
  Blizzard's player menu), message bubbles (in left, out right, date lines, clickable links), the
  input (Whispers.Send; a refused send keeps the text and says why). Read when the player clicks in or
  closes the window, never by just showing it.
  Conversation.Build(parent) / Show(conv) / Current() / Activate() / Copy() / HasFocus() / Render()
  ns.OpenWhisper(name)
]]
local _, ns = ...
local T, Widgets, Links, W, Safe = ns.Theme, ns.Widgets, ns.Links, ns.Whispers, ns.Safe
local L = ns.L

local Conversation = {}
ns.Conversation = Conversation

local HEADER = 44
local MUTED = "|cff8a8f9c"
local INPUT_H = 30
local RENDER_MAX = 80
local PAD_X, PAD_Y = 9, 6

local pane
local current
local bubbles, seps = {}, {}

local function DayKey(t) return date("%Y%m%d", t) end

local function DayLabel(t)
    local now = time()
    if DayKey(t) == DayKey(now) then return L.TODAY end
    if DayKey(t) == DayKey(now - 86400) then return L.YESTERDAY end
    return date("%d.%m.%Y", t)
end
Conversation._DayLabel = DayLabel

function Conversation.Current() return current end
function Conversation.HasFocus() return pane ~= nil and pane.input:HasFocus() end

-- realm, or "Battle.net  Joe#1234 - playing Bob (Realm)"
local function Subtitle(c)
    if not c.bn then return MUTED .. W.RealmOf(c) .. "|r" end
    local r, g, b = T.RGB("bn")
    local s = ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), L.BATTLENET)
    if c.target then s = s .. "  " .. MUTED .. c.target .. "|r" end
    local game = W.BNGame(c)
    if game then s = s .. MUTED .. " · " .. L.PLAYING:format(game) .. "|r" end
    return s
end

local function UpdateHeader()
    local c = current
    pane.who:SetShown(c ~= nil)
    if not c then return end
    pane.avatar:Set(c.name, c.class)
    pane.name:SetText(c.name or "?")
    if c.bn then
        pane.name:SetTextColor(T.RGB("bn"))
    else
        local r, g, b = T.ClassRGB(c.class)
        pane.name:SetTextColor(r, g, b, 1)
    end
    pane.sub:SetText(Subtitle(c))
    pane.input:SetPlaceholder(c.bn and "TYPE_BN" or "TYPE_MESSAGE")
end
Conversation.UpdateHeader = UpdateHeader

function Conversation.PlayerMenu(c)
    c = c or current
    if not c then return end
    local link
    if c.bn then
        if c.kname and c.bnID then link = ("BNplayer:%s:%d:0:BN_WHISPER:%s"):format(c.kname, c.bnID, c.kname) end
    elseif c.target then
        link = "player:" .. c.target
    end
    local setRef = _G["SetItemRef"]
    if link and setRef then pcall(setRef, link, "[" .. (c.name or "?") .. "]", "RightButton", _G["DEFAULT_CHAT_FRAME"]) end
end

-- the conversation as plain text: "17.11. 20:05  Name: text"
function Conversation.Copy()
    local c = current
    if not c then return end
    local me = Safe.Str(Safe.Call(UnitName, "player")) or "?"
    local lines = {}
    for _, m in ipairs(c.msgs or {}) do
        lines[#lines + 1] = { date("%d.%m. %H:%M", m.t) .. "  " .. (m.o and me or c.name or "?") .. ": " .. (m.m or "") }
    end
    ns.CopyBox.Show(lines)
end

function Conversation.Notice(reason)
    local text = reason == "lockdown" and L.LOCKDOWN or (reason == "offline" and L.OFFLINE or nil)
    if not text then return end
    pane.notice:SetText(text)
    pane.notice:Show()
    local token = {}
    pane.noticeToken = token
    C_Timer.After(6, function()
        if pane.noticeToken == token then pane.notice:Hide() end
    end)
end

local function NewBubble(content)
    local b = CreateFrame("Frame", nil, content)
    b.bg = T.Tex(b, "BACKGROUND", "bubbleIn", 0.95)
    b.bg:SetAllPoints()
    b.text = T.Text(b, ns.db.fontSize, "text", "OVERLAY", true)
    b.text:SetWordWrap(true)
    if b.text.SetNonSpaceWrap then b.text:SetNonSpaceWrap(true) end
    b.time = T.Text(b, 9, "textMuted")
    b.time:SetJustifyH("RIGHT")
    Links.Attach(b)
    b:SetScript("OnMouseUp", function() Conversation.Activate() end)
    return b
end

local function NewSeparator(content)
    local s = CreateFrame("Frame", nil, content)
    s:SetHeight(16)
    s.text = T.Text(s, 9, "textMuted")
    s.text:SetPoint("CENTER")
    s.text:SetJustifyH("CENTER")
    s.bg = T.Tex(s, "BACKGROUND", "ink", 0.06)
    s.bg:SetPoint("TOPLEFT", s.text, "TOPLEFT", -8, 3)
    s.bg:SetPoint("BOTTOMRIGHT", s.text, "BOTTOMRIGHT", 8, -3)
    return s
end

local function Layout(b, m, maxW)
    local size = ns.db.fontSize
    T.SetFont(b.text, size, true)
    local inner = maxW - 2 * PAD_X
    b.text:SetWidth(inner)
    b.text:SetText(ns.SpellLinks.Restore(m.m))
    local tw = math.min(math.ceil((b.text:GetStringWidth() or inner) + 1), inner)
    b.text:SetWidth(tw)
    local th = b.text:GetStringHeight() or size
    b.time:SetText(date("%H:%M", m.t))
    local timeW = b.time:GetStringWidth() or 28
    b:SetSize(math.max(tw, timeW) + 2 * PAD_X, th + 11 + 2 * PAD_Y)
    b.text:ClearAllPoints()
    b.text:SetPoint("TOPLEFT", PAD_X, -PAD_Y)
    b.time:ClearAllPoints()
    b.time:SetPoint("BOTTOMRIGHT", -PAD_X, PAD_Y - 2)
    T.Color(b.bg, m.o and "bubbleOut" or (current.bn and "bubbleBN" or "bubbleIn"), 0.95)
end

function Conversation.Render()
    if not pane then return end
    local c = current
    local msgs = c and c.msgs or {}
    local cw = pane.scroll:GetWidth() or 0
    if cw < 60 then cw = (pane:GetWidth() or 360) - 16 end
    local maxW = math.floor(cw * 0.75)
    local first = math.max(1, #msgs - RENDER_MAX + 1)
    local y, nb, nsep = -6, 0, 0
    local lastDay, lastOut, lastT
    for i = first, #msgs do
        local m = msgs[i]
        local day = DayKey(m.t)
        if day ~= lastDay then
            nsep = nsep + 1
            local s = seps[nsep] or NewSeparator(pane.content)
            seps[nsep] = s
            s.text:SetText(DayLabel(m.t))
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", pane.content, "TOPLEFT", 0, y - 4)
            s:SetPoint("TOPRIGHT", pane.content, "TOPRIGHT", 0, y - 4)
            s:Show()
            y = y - 26
            lastDay, lastOut = day, nil
        end
        local out = m.o == true
        local tight = lastOut == out and lastT and (m.t - lastT) < 120
        y = y - (tight and 2 or 6)
        nb = nb + 1
        local b = bubbles[nb] or NewBubble(pane.content)
        bubbles[nb] = b
        Layout(b, m, maxW)
        b:ClearAllPoints()
        if out then
            b:SetPoint("TOPRIGHT", pane.content, "TOPRIGHT", -2, y)
        else
            b:SetPoint("TOPLEFT", pane.content, "TOPLEFT", 2, y)
        end
        b:Show()
        y = y - b:GetHeight()
        lastOut, lastT = out, m.t
    end
    for i = nb + 1, #bubbles do bubbles[i]:Hide() end
    for i = nsep + 1, #seps do seps[i]:Hide() end
    pane.empty:SetText(c and L.TYPE_MESSAGE or L.PICK_CHAT)
    pane.empty:SetShown(#msgs == 0)
    pane.input:SetShown(c ~= nil)
    pane.content:SetWidth(cw)
    pane.content:SetHeight(math.max(1, -y + 6))
    local scroll = pane.scroll
    C_Timer.After(0, function()
        scroll:SetVerticalScroll(scroll:GetVerticalScrollRange() or 0)
    end)
end
Conversation.bubbles = bubbles

function Conversation.Show(conv)
    if not pane then return end
    if conv ~= current and pane.input:HasFocus() then pane.input:ClearFocus() end
    if conv ~= current then pane.input:SetText("") end
    current = conv
    pane.notice:Hide()
    UpdateHeader()
    Conversation.Render()
end

function Conversation.Activate()
    if not current then return end
    W.MarkRead(current)
    pane.input:SetFocus()
    if ns.Messenger then ns.Messenger.OnActivated() end
end

function Conversation.ApplyLook()
    if not pane then return end
    pane.input:SetSize2(ns.db.fontSize)
    pane.input:SetHeight(math.max(INPUT_H, ns.db.fontSize + 16))
    UpdateHeader()
    Conversation.Render()
end

function Conversation.Build(parent)
    pane = CreateFrame("Frame", nil, parent)
    Conversation.pane = pane

    local header = CreateFrame("Button", nil, pane)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER)
    header.bg = T.Tex(header, "BACKGROUND", "header", 0.6, 1)
    header.bg:SetAllPoints()
    local line = T.Tex(header, "BORDER", "ink", 0.08)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if current then ns.MessengerList.Menu(current) end
        else Conversation.Activate() end
    end)
    pane.header = header

    local who = CreateFrame("Frame", nil, header)
    who:SetAllPoints()
    pane.who = who
    pane.avatar = T.Avatar(who, 28)
    pane.avatar:SetPoint("LEFT", 12, 0)
    pane.name = T.Text(who, 13, "text")
    T.Own(pane.name)
    pane.name:SetPoint("TOPLEFT", pane.avatar, "TOPRIGHT", 10, -1)
    pane.name:SetPoint("RIGHT", header, "RIGHT", -110, 0)  -- room for the window controls
    pane.name:SetWordWrap(false)
    pane.sub = T.Text(who, 9, "textMuted")
    pane.sub:SetPoint("BOTTOMLEFT", pane.avatar, "BOTTOMRIGHT", 10, 1)
    pane.sub:SetPoint("RIGHT", header, "RIGHT", -110, 0)
    pane.sub:SetWordWrap(false)

    local body = CreateFrame("Frame", nil, pane)
    body:SetPoint("TOPLEFT", 0, -HEADER)
    body:SetPoint("BOTTOMRIGHT")
    body:EnableMouse(true)
    body:SetScript("OnMouseDown", function() Conversation.Activate() end)
    pane.body = body

    local input = Widgets.Input(body, "TYPE_MESSAGE", ns.db.fontSize)
    input:SetPoint("BOTTOMLEFT", 8, 8)
    input:SetPoint("BOTTOMRIGHT", -20, 8)
    input:SetHeight(INPUT_H)
    if input.SetMaxBytes then input:SetMaxBytes(1024) end
    input:SetScript("OnEnterPressed", function(eb)
        local text = eb:GetText()
        if text == nil or strtrim(text) == "" then eb:ClearFocus() return end
        local ok, why = W.Send(current, text)
        if ok then eb:SetText("") else Conversation.Notice(why) end
    end)
    input:HookScript("OnEditFocusGained", function(eb)
        Links.SetFocusBox(eb)
        if current then W.MarkRead(current) end
    end)
    input:HookScript("OnEditFocusLost", function(eb)
        if Links.FocusBox() == eb then Links.SetFocusBox(nil) end
    end)
    pane.input = input

    pane.notice = T.Text(body, 10, "danger")
    pane.notice:SetPoint("BOTTOMLEFT", input, "TOPLEFT", 2, 4)
    pane.notice:SetPoint("BOTTOMRIGHT", input, "TOPRIGHT", -2, 4)
    pane.notice:SetWordWrap(true)
    pane.notice:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", input, "TOPRIGHT", 0, 22)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local range = sf:GetVerticalScrollRange() or 0
        local v = (sf:GetVerticalScroll() or 0) - delta * 40
        sf:SetVerticalScroll(math.max(0, math.min(range, v)))
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(300, 1)
    scroll:SetScrollChild(content)
    pane.scroll, pane.content = scroll, content

    pane.empty = T.Text(body, 11, "textMuted")
    pane.empty:SetPoint("CENTER", scroll, "CENTER")
    pane.empty:SetJustifyH("CENTER")

    pane:SetScript("OnSizeChanged", function()
        if pane.sizeQueued then return end
        pane.sizeQueued = true
        C_Timer.After(0.05, function()
            pane.sizeQueued = false
            Conversation.Render()
        end)
    end)
    Conversation.Show(nil)
    return pane
end

function ns.OpenWhisper(name)
    if ns.Friends and ns.Friends.Resolve then name = ns.Friends.Resolve(name) end
    local c = W.Open(name)
    if c and ns.Messenger then ns.Messenger.Open(c, true) end
    return c
end

-- post-hooks on SendTell / SendBNetTell: Blizzard opens its box, a frame later the messenger
-- takes the focus (not in a lockdown: only Blizzard's box can send there). Cost: closing
-- Blizzard's box from our code writes its chat type tainted once; the next send rewrites it
local lastTell, lastTellTime
local function TakeOver(name, bn)
    name = Safe.Str(name)
    if not ns.active or not name or name == "" or Safe.InLockdown() then return end
    local now = GetTime()
    if name == lastTell and lastTellTime == now then return end  -- alias + util both hooked
    lastTell, lastTellTime = name, now
    C_Timer.After(0, function()
        if bn then
            local c = W.OpenBN(name)
            if c and ns.Messenger then ns.Messenger.Open(c, true) end
        else
            ns.OpenWhisper(name)
        end
    end)
end
Conversation._TakeOver = TakeOver

ns.OnReady(function()
    local util = _G["ChatFrameUtil"]
    local function Tell(name) TakeOver(name, false) end
    local function BNTell(name) TakeOver(name, true) end
    if type(util) == "table" then
        if type(util.SendTell) == "function" then hooksecurefunc(util, "SendTell", Tell) end
        if type(util.SendBNetTell) == "function" then hooksecurefunc(util, "SendBNetTell", BNTell) end
    end
    if type(_G["ChatFrame_SendTell"]) == "function" then hooksecurefunc("ChatFrame_SendTell", Tell) end
    if type(_G["ChatFrame_SendBNetTell"]) == "function" then hooksecurefunc("ChatFrame_SendBNetTell", BNTell) end
    -- "/w Bob " typed in Blizzard's box: the same hand-over
    ns.Input.OnWhisperMode(function(target, bn)
        if ns.db.slashWhisper then TakeOver(target, bn) end
    end)
end)
