--[[
  Layout: the browser's geometry from the window size alone. One header line:
  emblem and name left; search, filter, range and boost chips right, next to the
  close button. Narrower than Style.size.wide and they move to a toolbar line
  below. Below: the list (34 %) and the picked dungeon, each scrolling on its
  own; a resize grip bottom right, the size saved in the account layout.

  Layout.Measure(width, height) -> m { left, right, x, top, height, toolbar }
  Layout.Apply(frame)  /  Layout.Enable(frame)
]]
local _, ns = ...
local T, S = Sendit.Theme, ns.Style
local Layout = {}
ns.Layout = Layout

function Layout.Measure(width, height)
    local pad, size = S.space.pad, S.size
    local toolbar = width < size.wide
    local top = size.header + (toolbar and size.toolbar or 0)
    local inner = width - 2 * pad - S.space.gap
    local left = math.max(size.minLeft, math.floor(inner * 0.34))
    return { left = left, right = inner - left, x = pad + left + S.space.gap, top = top,
        height = math.max(160, height - top - pad), toolbar = toolbar }
end

local function Controls(f, m, w)
    local pad, gap = S.space.pad, 8
    local chips = f.filter:GetWidth() + gap + f.ahead:GetWidth() + gap + f.boost:GetWidth()
    for _, c in ipairs({ f.search, f.filter, f.ahead, f.boost }) do c:ClearAllPoints() end
    if m.toolbar then
        f.search:SetWidth(math.max(140, w - 2 * pad - chips - gap))
        f.search:SetPoint("TOPLEFT", pad, -(S.size.header + 4))
        f.filter:SetPoint("LEFT", f.search, "RIGHT", gap, 0)
        f.ahead:SetPoint("LEFT", f.filter, "RIGHT", gap, 0)
        f.boost:SetPoint("LEFT", f.ahead, "RIGHT", gap, 0)
        return
    end
    local room = w - pad - f.close:GetWidth() - 8 - chips - gap - f.titleWidth - 2 * pad
    f.search:SetWidth(math.max(140, math.min(S.size.search, room)))
    f.boost:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.ahead:SetPoint("RIGHT", f.boost, "LEFT", -gap, 0)
    f.filter:SetPoint("RIGHT", f.ahead, "LEFT", -gap, 0)
    f.search:SetPoint("RIGHT", f.filter, "LEFT", -gap, 0)
end

function Layout.Apply(f)
    local w, h = f:GetWidth(), f:GetHeight()
    local m = Layout.Measure(w, h)
    f.metrics = m
    Controls(f, m, w)
    f.list:ClearAllPoints()
    f.list:SetPoint("TOPLEFT", S.space.pad, -m.top)
    f.list:SetSize(m.left, m.height)
    f.resultScroll:SetSize(m.left, m.height - S.size.paneHead)
    f.resultScroll.content:SetWidth(m.left)
    f.detail:ClearAllPoints()
    f.detail:SetPoint("TOPLEFT", m.x, -m.top)
    f.detail:SetSize(m.right, m.height)
    f.detailScroll:SetSize(m.right, m.height - S.size.detailHead)
    f.detailScroll.content:SetWidth(m.right)
end

-- Three short diagonal strokes, drawn (no client glyph).
local function Grip(grip)
    local lines = {}
    for i = 1, 3 do
        local line = grip:CreateLine(nil, "ARTWORK")
        line:SetTexture(T.WHITE)
        line:SetThickness(1)
        line:SetStartPoint("BOTTOMRIGHT", grip, -2, 2 + i * 4)
        line:SetEndPoint("BOTTOMRIGHT", grip, -2 - i * 4, 2)
        lines[i] = line
    end
    return function(hot) for _, l in ipairs(lines) do T.Paint(l, hot and "accent" or "textMuted") end end
end

function Layout.Enable(f)
    f:SetResizable(true)
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    screenW, screenH = screenW > 0 and screenW or 1920, screenH > 0 and screenH or 1080
    f:SetResizeBounds(math.min(700, screenW), math.min(480, screenH), screenW, screenH)
    local db = ns.module.db or {}
    f:SetSize(math.min(screenW, math.max(700, tonumber(db.width) or 980)),
        math.min(screenH, math.max(480, tonumber(db.height) or 700)))
    local grip = CreateFrame("Button", nil, f)
    grip:SetFrameLevel(f:GetFrameLevel() + 50)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    local paint = Grip(grip)
    paint(false)
    grip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        if ns.module.db then ns.module.db.width, ns.module.db.height = f:GetWidth(), f:GetHeight() end
    end)
    grip:SetScript("OnEnter", function(self)
        paint(true)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:SetText(ns.L.resize, 1, 1, 1, 1, true) GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() paint(false) GameTooltip:Hide() end)
    f:SetScript("OnSizeChanged", function() ns.Window:Refresh() end)
end
