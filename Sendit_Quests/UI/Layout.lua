--[[
  Layout: the journal's geometry from the window size - header (controls move to a toolbar line when
  narrower than WIDE), list (35 %) and chain (65 %), resize grip.
  Layout.Measure(width, height) -> m;  Layout.Apply(frame);  Layout.Enable(frame)
]]
local _, ns = ...
local S = ns.Style
local Layout = {}
ns.Layout = Layout
local WIDE = 1040

function Layout.Measure(width, height)
    local pad, size = S.space.pad, S.size
    local toolbar = width < WIDE
    local top = size.header + (toolbar and size.toolbar or 0)
    local inner = width - 2 * pad - S.space.gap
    local left = math.max(size.minLeft, math.floor(inner * 0.35))
    return { left = left, right = inner - left, x = pad + left + S.space.gap, top = top,
        height = math.max(160, height - top - pad), toolbar = toolbar }
end

local function Controls(f, m, w)
    local pad, gap = S.space.pad, 8
    local chips = f.group:GetWidth() + gap + f.status:GetWidth() + gap + f.faction:GetWidth() + gap + f.boost:GetWidth()
    f.search:ClearAllPoints()
    f.group:ClearAllPoints()
    f.status:ClearAllPoints()
    f.faction:ClearAllPoints()
    f.boost:ClearAllPoints()
    if m.toolbar then
        local y = -(S.size.header + 4)
        f.search:SetWidth(math.max(140, w - 2 * pad - chips - gap))
        f.search:SetPoint("TOPLEFT", pad, y)
        f.group:SetPoint("LEFT", f.search, "RIGHT", gap, 0)
    else
        local room = w - pad - f.close:GetWidth() - 8 - chips - gap - f.titleWidth - 2 * pad
        f.search:SetWidth(math.max(140, math.min(S.size.search, room)))
        f.boost:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
        f.faction:SetPoint("RIGHT", f.boost, "LEFT", -gap, 0)
        f.status:SetPoint("RIGHT", f.faction, "LEFT", -gap, 0)
        f.group:SetPoint("RIGHT", f.status, "LEFT", -gap, 0)
        f.search:SetPoint("RIGHT", f.group, "LEFT", -gap, 0)
        return
    end
    f.status:SetPoint("LEFT", f.group, "RIGHT", gap, 0)
    f.faction:SetPoint("LEFT", f.status, "RIGHT", gap, 0)
    f.boost:SetPoint("LEFT", f.faction, "RIGHT", gap, 0)
end

function Layout.Apply(f)
    local w, h = f:GetWidth(), f:GetHeight()
    local m = Layout.Measure(w, h)
    f.metrics = m
    local pad = S.space.pad
    Controls(f, m, w)
    f.list:ClearAllPoints()
    f.list:SetPoint("TOPLEFT", pad, -m.top)
    f.list:SetSize(m.left, m.height)
    f.resultScroll:SetSize(m.left, m.height - S.size.paneHead)
    f.resultScroll.content:SetWidth(m.left)
    f.chain:ClearAllPoints()
    f.chain:SetPoint("TOPLEFT", m.x, -m.top)
    f.chain:SetSize(m.right, m.height)
    f.chainScroll:SetSize(m.right, m.height - S.size.chainHead)
    f.chainScroll.content:SetWidth(m.right)
    f.progress:SetWidth(m.right - 2 * S.space.inner)
end

function Layout.Enable(f)
    f:SetResizable(true)
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    screenW, screenH = screenW > 0 and screenW or 1920, screenH > 0 and screenH or 1080
    f:SetResizeBounds(math.min(680, screenW), math.min(480, screenH), screenW, screenH)
    local db = ns.module.db or {}
    f:SetSize(math.min(screenW, math.max(680, tonumber(db.width) or 960)),
        math.min(screenH, math.max(480, tonumber(db.height) or 720)))
    local grip = CreateFrame("Button", nil, f)
    f.resizeGrip = grip
    grip:SetFrameLevel(f:GetFrameLevel() + 50)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    local paintGrip = ns.Icons.Resize(grip)
    grip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        if ns.module.db then ns.module.db.width, ns.module.db.height = f:GetWidth(), f:GetHeight() end
    end)
    grip:SetScript("OnEnter", function(self)
        paintGrip(true)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:SetText(ns.L.resize, 1, 1, 1, 1, true) GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() paintGrip(false) GameTooltip:Hide() end)
    f:SetScript("OnSizeChanged", function() ns.Window:Refresh() end)
end
