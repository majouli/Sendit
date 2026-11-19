--[[
  Messenger: the one whisper window, like WhatsApp on the desktop: the
  conversation list on the left (UI/MessengerList.lua), the chosen
  conversation on the right (UI/Conversation.lua). This file is the window
  around them: header, position and size, minimize and its own lock, the
  open / close animation, the unread glow and what a change of the data
  means for the window.

  A new whisper while the window is closed: by default a bubble above the
  chat (UI/WhisperToasts.lua); with whisperAlert = "open" it opens the window
  on that conversation without taking the keyboard. While another
  conversation is shown it never switches; the row lights up. Unread until
  the user clicks into the conversation or closes the window; meanwhile the
  window breathes, minimized too (minimizing keeps it unread).

  Messenger.Open(conv, focus) / Show() / Close() / Toggle() / Refresh()
  Messenger.SetMinimized(on)
  Messenger.Showing(conv)  window shown, not minimized, on that conversation
  Messenger.IsMinimized()  the window is folded onto its header
  The friends list docked beside it: UI/FriendsPanel.lua (people icon here).
  Position: ns.acct.messenger = { x, y, w, h, minimized, locked }.
]]
local _, ns = ...
local T, Widgets, W = ns.Theme, ns.Widgets, ns.Whispers
local List = ns.MessengerList
local L = ns.L

local Messenger = {}
ns.Messenger = Messenger

local WIDTH, HEIGHT = 640, 440
local LIST_W = 236
local HEADER = 44

local frame, glow, glowAnim

local function Saved() return ns.acct.messenger end
local function Minimized() return Saved().minimized == true end
-- Its own lock, independent of the chat lock (a locked chat had pinned this
-- window too and it looked frozen).
local function Locked() return Saved().locked == true end
local function CanMove() return not Locked() end
local function IsOpen() return frame ~= nil and frame:IsShown() end

local function SavePosition()
    local d = Saved()
    d.x, d.y = frame:GetLeft(), frame:GetBottom()
    if not Minimized() then d.w, d.h = frame:GetWidth(), frame:GetHeight() end
end

---------------------------------------------------------------------------
-- Refresh: the list, the unread count in the header and the glow
---------------------------------------------------------------------------
function Messenger.Refresh()
    if not frame then return end
    List.Refresh()
    local unread = W.UnreadChats()
    frame.count:SetText(unread > 0 and ("(" .. unread .. ")") or "")
    -- unread anywhere: the window breathes until it is read
    glow:SetShown(unread > 0 and frame:IsShown())
    if unread > 0 then glowAnim:Play() else glowAnim:Stop() end
end

---------------------------------------------------------------------------
-- Position, size, minimize
---------------------------------------------------------------------------
local function Place()
    local d = Saved()
    local main = ns.Windows and ns.Windows.Main()
    frame:ClearAllPoints()
    if d.x then
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", d.x, d.y)
    elseif main then
        frame:SetPoint("BOTTOMLEFT", main.frame, "BOTTOMRIGHT", 12, 0)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetSize(d.w or WIDTH, Minimized() and HEADER or (d.h or HEIGHT))
    frame.body:SetShown(not Minimized())
    if ns.Conversation.pane then ns.Conversation.pane.body:SetShown(not Minimized()) end
    frame.grip:SetShown(not Minimized() and not Locked())
    frame.minBtn:SetKind(Minimized() and "restore" or "minimize")
    frame.lockBtn.active = Locked()
    frame.lockBtn:SetKind(Locked() and "lock" or "unlock")
    if ns.FriendsPanel then ns.FriendsPanel.Sync() end
end

function Messenger.IsMinimized() return Minimized() end

-- The people icon shows whether the friends list is open (and only while it is enabled).
function Messenger.UpdateFriendsButton()
    local b = frame and frame.friendsBtn
    if not b then return end
    b:SetShown(ns.FriendsPanel.Enabled())
    b.active = ns.FriendsPanel.IsOpen()
    b:SetKind("friends")
end

-- Minimizing keeps unread messages unread; restoring by itself does not read.
function Messenger.SetMinimized(on)
    if not frame then return end
    if on and not Minimized() then SavePosition() end
    Saved().minimized = on or nil
    if on and ns.Conversation.HasFocus() then ns.Conversation.pane.input:ClearFocus() end
    Place()
    if not on then ns.Conversation.Render() end
    Messenger.Refresh()
end

---------------------------------------------------------------------------
-- Open / close animation: the real window fades in while it glides a few
-- pixels up, and fades out while it sinks a little. Only alpha and
-- translation: both are cheap. Scaling was choppy in game (the client
-- re-renders every font string per scale step), and a zooming stand-in
-- frame flickered on its 1px edges and blinked at the hand-over.
-- No SetToFinalAlpha (Fade owns frame alpha): the window is hidden by a
-- timer just before its fade-out ends.
---------------------------------------------------------------------------
local OPEN, CLOSE, RISE, SINK = 0.18, 0.12, 12, 6

local function BuildAnimations()
    local open = frame:CreateAnimationGroup()
    local down = open:CreateAnimation("Translation")  -- jump below the target, invisibly
    down:SetOffset(0, -RISE)
    down:SetDuration(0)
    down:SetOrder(1)
    local up = open:CreateAnimation("Translation")
    up:SetOffset(0, RISE)
    up:SetDuration(OPEN)
    up:SetSmoothing("OUT")
    up:SetOrder(2)
    local show = open:CreateAnimation("Alpha")
    show:SetFromAlpha(0)
    show:SetToAlpha(1)
    show:SetDuration(OPEN)
    show:SetSmoothing("OUT")
    show:SetOrder(2)
    frame.fadeIn = open

    local close = frame:CreateAnimationGroup()
    local sink = close:CreateAnimation("Translation")
    sink:SetOffset(0, -SINK)
    sink:SetDuration(CLOSE)
    sink:SetSmoothing("IN")
    local hide = close:CreateAnimation("Alpha")
    hide:SetFromAlpha(1)
    hide:SetToAlpha(0)
    hide:SetDuration(CLOSE)
    hide:SetSmoothing("IN")
    frame.fadeOut = close
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
-- Left header: title and unread count; a drag handle for the window.
local function BuildHeader()
    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetSize(LIST_W, HEADER)
    header.bg = T.Tex(header, "BACKGROUND", "header", 1, 1)
    header.bg:SetAllPoints()
    Widgets.Drag(header, frame, CanMove, SavePosition)
    header:SetScript("OnClick", function() if Minimized() then Messenger.SetMinimized(false) end end)
    frame.title = T.Text(header, 14, "text")
    frame.title:SetPoint("LEFT", 14, 0)
    frame.count = T.Text(header, 12, "accent")
    frame.count:SetPoint("LEFT", frame.title, "RIGHT", 6, 0)
end

-- Window controls, top right over the conversation header.
local function BuildControls()
    local function OnTop(b) b:SetFrameLevel(frame:GetFrameLevel() + 10) end
    local close = Widgets.IconButton(frame, "close", "CLOSE", Messenger.Close)
    close:SetPoint("TOPRIGHT", -8, -12)
    OnTop(close)
    frame.minBtn = Widgets.IconButton(frame, "minimize", function()
        return Minimized() and L.RESTORE or L.MINIMIZE
    end, function() Messenger.SetMinimized(not Minimized()) end)
    frame.minBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
    OnTop(frame.minBtn)
    frame.lockBtn = Widgets.IconButton(frame, "unlock", function()
        return Locked() and L.LOCKED or L.UNLOCKED
    end, function()
        Saved().locked = not Locked() or nil
        Place()
    end)
    frame.lockBtn:SetPoint("RIGHT", frame.minBtn, "LEFT", -2, 0)
    OnTop(frame.lockBtn)
    frame.friendsBtn = Widgets.IconButton(frame, "friends", "FRIENDS_TIP", function() ns.FriendsPanel.Toggle() end)
    frame.friendsBtn:SetPoint("RIGHT", frame.lockBtn, "LEFT", -2, 0)
    OnTop(frame.friendsBtn)
    frame.copyBtn = Widgets.IconButton(frame, "copy", "COPY_TEXT", function() ns.Conversation.Copy() end)
    frame.copyBtn:SetPoint("RIGHT", frame.friendsBtn, "LEFT", -2, 0)
    OnTop(frame.copyBtn)
end

-- Unread glow: an accent frame just outside the border, breathing.
local function BuildGlow()
    glow = CreateFrame("Frame", nil, frame)
    glow:SetPoint("TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", 3, -3)
    glow:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = T.Tex(glow, "BACKGROUND", "accent", 0.9)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(2)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(2)
        end
    end
    glowAnim = glow:CreateAnimationGroup()
    glowAnim:SetLooping("BOUNCE")
    local breathe = glowAnim:CreateAnimation("Alpha")
    breathe:SetFromAlpha(0.15)
    breathe:SetToAlpha(1)
    breathe:SetDuration(0.8)
    breathe:SetSmoothing("IN_OUT")
    glow:Hide()
    frame.glow = glow
end

-- Body: the list on the left, the conversation on the right.
local function BuildBody()
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 0, -HEADER)
    body:SetPoint("BOTTOMRIGHT")
    frame.body = body

    local column = List.Build(body, LIST_W)
    column:SetPoint("TOPLEFT")
    column:SetPoint("BOTTOMLEFT")
    local divider = T.Tex(frame, "BORDER", "ink", 0.10)
    divider:SetPoint("TOPLEFT", LIST_W, 0)
    divider:SetPoint("BOTTOMLEFT", LIST_W, 0)
    divider:SetWidth(1)

    -- the conversation's header shares the top row and moves the window too
    local pane = ns.Conversation.Build(frame)
    pane:SetPoint("TOPLEFT", LIST_W + 1, 0)
    pane:SetPoint("BOTTOMRIGHT")
    frame.pane = pane
    Widgets.Drag(ns.Conversation.pane.header, frame, CanMove, SavePosition)
end

local function Build()
    frame = T.Panel(UIParent, "MEDIUM", "SenditMessenger")
    T.Decorate(frame, "dialog", { title = L.MESSAGES, icon = "Interface\\Icons\\INV_Letter_15", level = 12 })
    BuildAnimations()
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    Widgets.Bounds(frame, 480, 280, 1400, 1000)
    BuildHeader()
    BuildControls()
    BuildGlow()
    BuildBody()
    frame.grip = Widgets.Grip(frame, SavePosition)
    frame:SetScript("OnShow", Messenger.Refresh)
    frame:SetScript("OnHide", function() glowAnim:Stop() end)
    table.insert(UISpecialFrames, "SenditMessenger")
    Place()
end

-- Azeroth: the gold banner carries the title, the header keeps the count.
local function UpdateTitle()
    frame.title:SetText(T.style == "azeroth" and "" or L.MESSAGES)
end

---------------------------------------------------------------------------
-- Show / open / close
---------------------------------------------------------------------------
function Messenger.Show()
    if not frame then Build() end
    Place()
    UpdateTitle()
    local wasShown = frame:IsShown() and not frame.closing
    if frame.closing then
        frame.closing = nil
        frame.fadeOut:Stop()
    end
    frame:Show()
    frame:Raise()
    if ns.FriendsPanel then ns.FriendsPanel.Sync() end  -- after Show: it docks to a shown window
    if not wasShown and ns.Design().animations then
        frame.fadeIn:Stop()
        frame.fadeIn:Play()
    end
    if not ns.Conversation.Current() then
        local first = List.First()
        if first then ns.Conversation.Show(first) end
    end
    Messenger.Refresh()
end

-- Show a conversation (the list switches to its tab); focus = the user asked
-- for it (click, link, name): restore, read, cursor in the input.
function Messenger.Open(conv, focus)
    if not conv then return end
    if not frame then Build() end
    List.SetView(List.ViewOf(conv))
    if focus and Minimized() then Messenger.SetMinimized(false) end
    Messenger.Show()
    ns.Conversation.Show(conv)
    if focus then ns.Conversation.Activate() end
    Messenger.Refresh()
end

-- Closing counts as read for the conversation shown.
function Messenger.Close()
    if not frame or not frame:IsShown() or frame.closing then return end
    local cur = ns.Conversation.Current()
    if cur then W.MarkRead(cur) end
    if ns.Conversation.HasFocus() then ns.Conversation.pane.input:ClearFocus() end
    if not ns.Design().animations then
        frame:Hide()
        return
    end
    local token = {}
    frame.closing = token
    frame.fadeIn:Stop()
    frame.fadeOut:Play()
    C_Timer.After(CLOSE * 0.9, function()
        if frame.closing ~= token then return end  -- reopened meanwhile
        frame.closing = nil
        frame:Hide()
        frame.fadeOut:Stop()
    end)
end

function Messenger.IsOpen() return IsOpen() and not frame.closing end

function Messenger.Toggle()
    if IsOpen() and not frame.closing then Messenger.Close() else Messenger.Show() end
end

function Messenger.OnActivated()
    if Minimized() then Messenger.SetMinimized(false) end
    Messenger.Refresh()
end

function Messenger.Frame() return frame end

function Messenger.Showing(conv)
    return IsOpen() and not frame.closing and not Minimized()
        and conv ~= nil and ns.Conversation.Current() == conv
end

---------------------------------------------------------------------------
-- What a change of the data means for the window (W.OnChange)
---------------------------------------------------------------------------
local function OnChange(conv, msg, incoming)
    local arrived = msg ~= nil and incoming
    local autoOpen = arrived and ns.db.whisperAlert == "open" and not IsOpen()
    if not frame and not autoOpen then return end
    local cur = ns.Conversation.Current()
    local listed = List.Holds(conv)
    -- deleted, archived or restored while shown: show the next one of the list
    if not listed and cur == conv then
        cur = List.First()
        ns.Conversation.Show(cur)
    end
    if autoOpen then
        Messenger.Open(conv, false)
        return
    end
    if listed and conv == cur then
        if msg then ns.Conversation.Render() end
        ns.Conversation.UpdateHeader()
    elseif listed and not cur and IsOpen() then
        ns.Conversation.Show(conv)
    end
    Messenger.Refresh()
end
Messenger._OnChange = OnChange

ns.OnReady(function()
    W.viewing = function(key)
        local cur = ns.Conversation.Current()
        return IsOpen() and not Minimized() and cur ~= nil and cur.key == key and ns.Conversation.HasFocus()
    end
    W.OnChange(OnChange)
    ns.OnChanged(function()
        if not frame then return end
        T.SetBorder(frame, math.max(1, ns.db.border))
        UpdateTitle()
        Place()
        ns.Conversation.ApplyLook()
    end)
end)

Sendit:AddLauncher({
    key = "chat", order = 10, icon = "Interface\\AddOns\\Sendit_Chat\\Media\\Icon", title = function() return ns.L.MESSENGER end,
    toggle = function() if ns.active then Messenger.Toggle() end end,
    shown = Messenger.IsOpen,
})
