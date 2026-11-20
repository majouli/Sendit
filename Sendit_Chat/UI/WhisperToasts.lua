--[[
  WhisperToasts: a new whisper as a small bubble right above the main chat (whisperAlert "toast") - one
  per conversation (latest text, unread count), up to MAX, HOLD s each; left click opens the messenger on
  it, right click dismisses; gone once read or shown. Toasts.Notice shows other notices in the same look.
  Its own top-level frame (no "chat" in the name), on the main window; loot cards stack on top.
]]
local _, ns = ...
local T, Widgets, Links, W = ns.Theme, ns.Widgets, ns.Links, ns.Whispers

local Toasts = {}
ns.WhisperToasts = Toasts

local MAX = 3
local HOLD = 8
local WIDTH, H, GAP, AVATAR = 290, 56, 6, 32

local stack
local toasts = {}  -- toast frames; .conv while live
local seq = 0  -- arrival order

local function Live()
    local list = {}
    for _, t in ipairs(toasts) do if t.conv then list[#list + 1] = t end end
    table.sort(list, function(a, b) return a.born > b.born end)
    return list
end

local function Layout()
    if not stack then return end
    local list = Live()
    for i, t in ipairs(list) do
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", stack, "BOTTOMLEFT", 0, (i - 1) * (H + GAP))
    end
    stack:SetHeight(#list > 0 and #list * (H + GAP) or 0.01)
    stack:SetShown(#list > 0)
end

local function Remove(t)
    t.conv, t.token = nil, nil
    t.outAnim:Stop()
    t:Hide()
    Layout()
end

local function FadeOut(t, token)
    if t.token ~= token or not t.conv then return end
    if t:IsMouseOver() then
        C_Timer.After(1, function() FadeOut(t, token) end)
        return
    end
    t.outAnim:Play()
    C_Timer.After(0.4, function() if t.token == token then Remove(t) end end)
end

local function NewToast()
    local t = CreateFrame("Button", nil, stack)
    t:SetSize(WIDTH, H)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t.bg = T.Tex(t, "BACKGROUND", "bg", 0.95)
    t.bg:SetAllPoints()
    t.hover = T.Tex(t, "BACKGROUND", "ink", 0, 1)
    t.hover:SetAllPoints()
    T.Border(t, 1)
    t.bar = T.Tex(t, "ARTWORK", "accent", 1)
    T.Own(t.bar)
    t.bar:SetPoint("TOPLEFT"); t.bar:SetPoint("BOTTOMLEFT"); t.bar:SetWidth(3)

    t.avatar = T.Avatar(t, AVATAR)
    t.avatar:SetPoint("LEFT", 12, 0)
    t.name = T.Text(t, 12, "text")
    T.Own(t.name)
    t.name:SetPoint("TOPLEFT", t.avatar, "TOPRIGHT", 10, -1)
    t.name:SetPoint("RIGHT", t, "RIGHT", -52, 0)
    t.name:SetWordWrap(false)
    t.time = T.Text(t, 10, "textMuted")
    t.time:SetPoint("TOPRIGHT", -10, -9)
    t.time:SetJustifyH("RIGHT")
    t.text = T.Text(t, 11, "text", "OVERLAY", true)
    t.text:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -3)
    t.text:SetPoint("RIGHT", t, "RIGHT", -34, 0)
    t.text:SetWordWrap(false)
    t.badge = Widgets.Badge(t)
    t.badge:SetPoint("BOTTOMRIGHT", -10, 9)

    t.inAnim = t:CreateAnimationGroup()
    local from = t.inAnim:CreateAnimation("Translation")
    from:SetOffset(0, -10)
    from:SetDuration(0)
    from:SetOrder(1)
    local rise = t.inAnim:CreateAnimation("Translation")
    rise:SetOffset(0, 10)
    rise:SetDuration(0.25)
    rise:SetSmoothing("OUT")
    rise:SetOrder(2)
    local appear = t.inAnim:CreateAnimation("Alpha")
    appear:SetFromAlpha(0)
    appear:SetToAlpha(1)
    appear:SetDuration(0.25)
    appear:SetOrder(2)

    t.outAnim = t:CreateAnimationGroup()
    local vanish = t.outAnim:CreateAnimation("Alpha")
    vanish:SetFromAlpha(1)
    vanish:SetToAlpha(0)
    vanish:SetDuration(0.4)

    t:SetScript("OnEnter", function(self) T.Color(self.hover, "ink", 0.06) end)
    t:SetScript("OnLeave", function(self) T.Color(self.hover, "ink", 0) end)
    t:SetScript("OnClick", function(self, button)
        local conv, onClick = self.conv, self.onClick
        Remove(self)
        if button ~= "LeftButton" then return end
        if onClick then onClick() elseif conv and W.Get(conv.key) then ns.Messenger.Open(conv, true) end
    end)
    return t
end

local function Acquire(conv)
    for _, t in ipairs(toasts) do
        if t.conv == conv then return t, true end
    end
    for _, t in ipairs(toasts) do
        if not t.conv then return t, false end
    end
    if #toasts < MAX then
        local t = NewToast()
        toasts[#toasts + 1] = t
        return t, false
    end
    local list = Live()  -- full: the oldest makes room
    return list[#list], false
end

local function Render(t, again, who, text, when, badge)
    seq = seq + 1
    t.born = seq
    t.avatar:Set(who.name, who.class)
    local r, g, b = T.ClassRGB(who.class)
    if who.bn then r, g, b = T.RGB("bn") end
    t.name:SetText(who.name or "?")
    t.name:SetTextColor(r, g, b, 1)
    t.bar:SetVertexColor(r, g, b, 1)
    t.time:SetText(date("%H:%M", when or time()))
    t.text:SetText(text)
    t.badge:Set(badge)
    t.outAnim:Stop()
    t:SetAlpha(1)
    t:Show()
    Layout()
    if not again and ns.Design().animations then t.inAnim:Play() end
    local token = {}
    t.token = token
    C_Timer.After(HOLD, function() FadeOut(t, token) end)
    return t
end

function Toasts.Show(conv, msg)
    if not stack or not conv or not msg then return nil end
    local t, again = Acquire(conv)
    t.conv, t.onClick = conv, nil
    local text = Links.Plain(msg.m or ""):gsub("[\r\n]+", " ")
    return Render(t, again, conv, text, msg.t, conv.unread or 1)
end

-- a short notice in the same look: n = { key, name, class, bn, text, onClick }
function Toasts.Notice(n)
    if not stack or not n then return nil end
    local t, again
    for _, x in ipairs(toasts) do
        if x.conv and x.conv.noticeKey == n.key then t, again = x, true end
    end
    if not t then t, again = Acquire({}) end
    t.conv = { noticeKey = n.key, name = n.name, class = n.class, bn = n.bn }
    t.onClick = n.onClick
    return Render(t, again, t.conv, n.text or "", nil, 0)
end

function Toasts.Clear(conv)
    for _, t in ipairs(toasts) do
        if t.conv and (conv == nil or t.conv == conv) then Remove(t) end
    end
end

function Toasts.Count() return #Live() end

-- directly on the main window, following it
function Toasts.Anchor()
    local main = ns.Windows.Main()
    if not stack or not main then return end
    stack:ClearAllPoints()
    stack:SetPoint("BOTTOMLEFT", main.frame, "TOPLEFT", 0, 8)
end

function Toasts.Frame() return stack end

local function OnChange(conv, msg, incoming)
    if not stack then return end
    if not W.Get(conv.key) or conv.archived or (conv.unread or 0) == 0 or W.viewing(conv.key) then
        Toasts.Clear(conv)  -- deleted, archived or read
        return
    end
    if not (msg and incoming) or ns.db.whisperAlert ~= "toast" then return end
    if ns.Messenger.Showing(conv) then return end
    Toasts.Show(conv, msg)
end
Toasts._OnChange = OnChange

ns.OnReady(function()
    stack = CreateFrame("Frame", "SenditWhisperToasts", UIParent)
    stack:SetSize(WIDTH, 0.01)
    stack:SetFrameStrata("MEDIUM")
    stack:Hide()
    Toasts.Anchor()
    if ns.LootCards and ns.LootCards.Anchor then ns.LootCards.Anchor() end
    W.OnChange(OnChange)
end)
