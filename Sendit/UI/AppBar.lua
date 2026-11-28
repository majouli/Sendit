--[[
  AppBar: a movable launcher - a round handle slides a tray of module windows out and in (towards the
  wider side of the screen); drag moves it, right click opens the Sendit window. Only windows here.
  The tray is a grid: as many columns as fit beside the handle (at most MAX_COLS, rows balanced), more
  rows grow away from the nearer screen edge, so it never runs off screen or over half of it.
  Sendit:AddLauncher{ key, title (string | fn), icon, toggle(), shown() -> bool, order } (also listed in
  the Sendit window's sidebar); AppBar.Launchers() / IsShown(def)
  Account: ns.db.appbar = { hide, open, point }. Motion: alpha + translation, off with animations.
]]
local _, ns = ...

local T, W = ns.Theme, ns.Widgets
local Resolve = ns.Locale.Resolve
local L = ns.L

local AppBar = {}
ns.AppBar = AppBar

local HANDLE, CELL, ICON, GAP, PAD, SPACE, MAX_COLS = 40, 40, 30, 2, 5, 6, 6
local SLIDE, DURATION, POLL = 20, 0.22, 0.3
local CLICK_AFTER_DRAG = 0.2
local DEFAULT_POINT = { "RIGHT", "RIGHT", -70, 120 }

local launchers = {}
local handle, tray
local cells = {}

local function Tx(key) return ns.Locale.Text(L, key) end

function ns:AddLauncher(def)
    launchers[#launchers + 1] = def
    table.sort(launchers, function(a, b)
        if (a.order or 50) ~= (b.order or 50) then return (a.order or 50) < (b.order or 50) end
        return a.key < b.key
    end)
    if ns.db then AppBar.Refresh() end
    if ns.Options._Nav() then ns.Options:Rebuild() end
end

function AppBar.Launchers() return launchers end

function AppBar.OpensRight()
    local x = handle and handle:GetCenter()
    local width = UIParent:GetWidth()
    return not x or not width or x < width / 2
end

local function IsShown(def)
    if not def.shown then return false end
    local ok, on = pcall(def.shown)
    return ok and on == true
end
AppBar.IsShown = IsShown

local function Cell(i)
    local c = cells[i]
    if c then return c end
    c = CreateFrame("Button", nil, tray)
    c:SetSize(CELL, CELL)
    c:RegisterForClicks("LeftButtonUp")
    T.Fill(c, "hover", "HIGHLIGHT"):SetAllPoints()
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(ICON, ICON)
    c.icon:SetPoint("CENTER", 0, 1)
    c.dot = T.Circle(c, "accent", 5, "OVERLAY")
    c.dot:SetPoint("BOTTOM", 0, 1)
    c:SetScript("OnClick", function(self)
        if self.def and self.def.toggle then self.def.toggle() end
        C_Timer.After(0.05, AppBar.Paint)
    end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Resolve(self.def.title) or self.def.key, T.Color("text"))
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[i] = c
    return c
end

function AppBar.Paint()
    if not tray or not tray:IsShown() then return end
    for _, c in ipairs(cells) do
        if c:IsShown() then c.dot:SetShown(IsShown(c.def)) end
    end
end

-- columns that fit beside the handle on the open side, rows balanced: 9 launchers -> 5 + 4
local function Grid(n, right)
    local screen = UIParent:GetWidth() or 0
    local room = right and (screen - (handle:GetRight() or 0)) or (handle:GetLeft() or screen)
    local fit = math.floor((room - SPACE - 2 * PAD + GAP) / (CELL + GAP))
    local cols = math.max(1, math.min(n, MAX_COLS, fit))
    local rows = math.ceil(n / cols)
    return math.ceil(n / rows), rows
end

local function Place()
    local right = AppBar.OpensRight()
    local n = #launchers
    local cols, rows = Grid(math.max(1, n), right)
    tray:SetSize(PAD * 2 + cols * CELL + (cols - 1) * GAP, PAD * 2 + rows * CELL + (rows - 1) * GAP)
    local _, y = handle:GetCenter()
    local up = rows > 1 and y ~= nil and y < (UIParent:GetHeight() or 0) / 2
    local side, edge = right and "LEFT" or "RIGHT", rows == 1 and "" or (up and "BOTTOM" or "TOP")
    tray:ClearAllPoints()
    tray:SetPoint(edge .. side, handle, edge .. (right and "RIGHT" or "LEFT"), right and SPACE or -SPACE, 0)
    local corner = (up and "BOTTOM" or "TOP") .. side
    for i = 1, n do
        local c = cells[i]
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, dy = PAD + col * (CELL + GAP), PAD + row * (CELL + GAP)
        c:ClearAllPoints()
        c:SetPoint(corner, right and x or -x, up and dy or -dy)
    end
    return right
end

local function Layout()
    for i, def in ipairs(launchers) do
        local c = Cell(i)
        c.def = def
        c.icon:SetTexture(def.icon or 134400)
        c:Show()
    end
    for i = #launchers + 1, #cells do cells[i]:Hide() end
end

local function Motion()
    local ag = tray:CreateAnimationGroup()
    ag.from = ag:CreateAnimation("Translation")
    ag.from:SetDuration(0)
    ag.from:SetOrder(1)
    ag.move = ag:CreateAnimation("Translation")
    ag.move:SetOrder(2)
    ag.move:SetSmoothing("OUT")
    ag.fade = ag:CreateAnimation("Alpha")
    ag.fade:SetOrder(2)
    ag:SetScript("OnFinished", function(self)
        if self.closing then tray:Hide() end
        tray:SetAlpha(1)
    end)
    return ag
end

local function Slide(open)
    local ag = tray.motion
    ag:Stop()
    ag.closing = not open
    local right = Place()
    if not T.Animated() then
        tray:SetShown(open)
        return
    end
    local dx = right and -SLIDE or SLIDE
    ag.from:SetOffset(open and dx or 0, 0)
    ag.move:SetOffset(open and -dx or dx, 0)
    ag.move:SetDuration(DURATION)
    ag.fade:SetFromAlpha(open and 0 or 1)
    ag.fade:SetToAlpha(open and 1 or 0)
    ag.fade:SetDuration(DURATION)
    tray:Show()
    if not open then tray:SetAlpha(1) end
    ag:Play()
end

function AppBar.IsOpen() return tray ~= nil and tray:IsShown() and not tray.motion.closing end

function AppBar.SetOpen(open)
    if not handle then return end
    ns.db.appbar.open = open
    if open == AppBar.IsOpen() then return end
    Slide(open)
    AppBar.Paint()
end

function AppBar.Toggle() AppBar.SetOpen(not AppBar.IsOpen()) end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, AppBar.OpensRight() and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    GameTooltip:SetText("Sendit", T.Color("accent"))
    local r, g, b = T.Color("textDim")
    for _, key in ipairs({ "APPBAR_CLICK", "APPBAR_RIGHT", "APPBAR_DRAG" }) do
        GameTooltip:AddLine(L[key], r, g, b)
    end
    GameTooltip:Show()
end

local function Create()
    handle = CreateFrame("Button", "SenditAppBar", UIParent)
    ns.ownFrames[handle] = true
    handle:SetSize(HANDLE, HANDLE)
    handle:SetFrameStrata("HIGH")
    handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    handle.ring = T.Circle(handle, "border", HANDLE + 2, "BACKGROUND")
    handle.ring:SetDrawLayer("BACKGROUND", -1)
    handle.ring:SetPoint("CENTER")
    T.Circle(handle, "panel", HANDLE, "BACKGROUND"):SetPoint("CENTER")
    handle.icon = handle:CreateTexture(nil, "ARTWORK")
    handle.icon:SetTexture(ns.ICON)
    handle.icon:SetSize(HANDLE - 10, HANDLE - 10)
    handle.icon:SetPoint("CENTER")
    T.Circle(handle, "hover", HANDLE, "HIGHLIGHT"):SetPoint("CENTER")

    tray = CreateFrame("Frame", nil, handle)
    tray:SetClampedToScreen(true)
    tray:Hide()
    T.Fill(tray, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(tray, "border")
    tray.motion = Motion()
    local since = 0
    tray:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < POLL then return end
        since = 0
        AppBar.Paint()
    end)

    handle:SetScript("OnClick", function(_, mouse)
        if handle.droppedAt and GetTime() - handle.droppedAt < CLICK_AFTER_DRAG then return end
        if mouse == "RightButton" then ns.Options:Toggle() else AppBar.Toggle() end
    end)
    handle:SetScript("OnEnter", ShowTooltip)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    W.Movable(handle, handle, {
        store = ns.db.appbar, key = "point", default = DEFAULT_POINT,
        onDrop = function()
            handle.droppedAt = GetTime()
            if tray:IsShown() then Place() end
        end,
    })
end

function AppBar.Refresh()
    if not ns.db then return end
    local show = not ns.db.appbar.hide and #launchers > 0
    if not handle then
        if not show then return end
        Create()
    end
    Layout()
    handle:SetShown(show)
    if show and ns.db.appbar.open and not tray:IsShown() then
        Place()
        tray:Show()
    end
    if tray:IsShown() then Place() end
    AppBar.Paint()
end

function AppBar.Handle() return handle end

ns.OnReady(AppBar.Refresh)
ns.OnSettingsChanged(AppBar.Refresh)
