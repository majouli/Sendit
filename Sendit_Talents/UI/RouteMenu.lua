--[[
  RouteMenu: the route button and its build panel. The panel belongs to the talent window (closes
  with it, never covers the rest of the screen), opens upwards and shows one column per tree; every
  build is a card: name, role and use, a bar of its points per tree; the tooltip adds the details.
  A click outside the panel closes it.
  RouteMenu.Create(parent, width, columns, get, set) -> button;  button:Refresh()
  columns() -> { { title, { key, name, use = text, points = { n1, n2, n3 }, main = tree index,
                 label = closed text, tip = RouteText.Tip lines }, ... }, ... }, off = { key, text }
]]
local _, ns = ...
local T, W = Sendit.Theme, Sendit.Widgets

local RouteMenu = {}
ns.RouteMenu = RouteMenu

local CARD, HEAD, PAD, COL, GAP = 50, 30, 12, 230, 4

local function ShowTip(card)
    if not card.tip then return end
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    for i, line in ipairs(card.tip) do
        if i == 1 then
            GameTooltip:SetText(line[1], T.Color(line[2]))
        elseif line[1] then
            local r, g, b = T.Color(line[2])
            GameTooltip:AddLine(line[1], r, g, b, true)
        else
            GameTooltip:AddLine(" ")
        end
    end
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

local function Card(panel, i)
    local c = panel.cards[i]
    if c then return c end
    c = CreateFrame("Button", nil, panel)
    c:SetSize(COL - 2 * GAP, CARD)
    c.current = T.Fill(c, "selected", "BACKGROUND")
    c.current:SetAllPoints()
    T.Fill(c, "hover", "HIGHLIGHT"):SetAllPoints()
    c.name = T.Text(c, "label", "text")
    c.name:SetPoint("TOPLEFT", PAD, -8)
    c.name:SetPoint("RIGHT", -PAD, 0)
    c.use = T.Text(c, "small", "textDim")
    c.use:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    c.use:SetPoint("RIGHT", -PAD, 0)
    c.bar = {}
    for t = 1, 3 do
        c.bar[t] = T.Fill(c, "border", "ARTWORK")
        c.bar[t]:SetHeight(3)
    end
    c:SetScript("OnEnter", ShowTip)
    c:SetScript("OnLeave", HideTip)
    panel.cards[i] = c
    return c
end

-- points per tree as one bar: the main tree in the accent colour, gaps between trees
local function Bar(c, points, main)
    local total = 0
    for _, n in ipairs(points) do total = total + n end
    local width, x = COL - 2 * GAP - 2 * PAD, 0
    for t = 1, 3 do
        local seg = c.bar[t]
        local n = points[t] or 0
        seg:ClearAllPoints()
        if n > 0 and total > 0 then
            local w = math.max(2, width * n / total - (x > 0 and 2 or 0))
            seg:SetPoint("BOTTOMLEFT", PAD + x + (x > 0 and 2 or 0), 8)
            seg:SetWidth(w)
            T.Paint(seg, t == main and "accent" or "textMuted")
            seg:Show()
            x = x + width * n / total
        else
            seg:Hide()
        end
    end
end

local function Head(panel, i)
    local h = panel.heads[i]
    if h then return h end
    h = CreateFrame("Frame", nil, panel)
    h:SetSize(COL - 2 * GAP, HEAD)
    h.text = T.Text(h, "label", "textDim")
    h.text:SetPoint("BOTTOMLEFT", PAD, 9)
    h.line = T.Fill(h, "border", "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT", PAD, 3)
    h.line:SetPoint("BOTTOMRIGHT", -PAD, 3)
    panel.heads[i] = h
    return h
end

local function Fill(panel, columns, current, onSelect)
    for _, h in ipairs(panel.heads) do h:Hide() end
    for _, c in ipairs(panel.cards) do c:Hide() end
    local n, rows = 0, 0
    local function Pick(key)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        panel:Hide()
        onSelect(key)
    end
    for col, column in ipairs(columns) do
        local x = GAP + (col - 1) * COL
        local h = Head(panel, col)
        h:SetPoint("TOPLEFT", x, -GAP)
        h.text:SetText(column[1])
        h:Show()
        for i = 2, #column do
            local entry = column[i]
            n = n + 1
            local c = Card(panel, n)
            c:SetPoint("TOPLEFT", x, -GAP - HEAD - (i - 2) * (CARD + 2))
            c.name:SetText(entry[2])
            c.use:SetText(entry.use)
            c.tip = entry.tip
            local on = entry[1] == current
            c.current:SetShown(on)
            T.Paint(c.name, on and "accent" or "text")
            Bar(c, entry.points, entry.main)
            c:SetScript("OnClick", function() Pick(entry[1]) end)
            c:Show()
        end
        rows = math.max(rows, #column - 1)
    end
    local bottom = GAP + HEAD + rows * (CARD + 2) + 6
    panel.off:ClearAllPoints()
    panel.off:SetPoint("TOPLEFT", GAP, -bottom)
    panel.off:SetPoint("RIGHT", -GAP, 0)
    panel.off.text:SetText(columns.off[2])
    local on = columns.off[1] == current
    T.Paint(panel.off.text, on and "accent" or "textDim")
    panel.off:SetScript("OnClick", function() Pick(columns.off[1]) end)
    panel:SetSize(2 * GAP + math.max(1, #columns) * COL, bottom + 28 + GAP)
end

local function Panel(button)
    local panel = CreateFrame("Frame", nil, button:GetParent())
    panel:SetFrameStrata("FULLSCREEN")  -- above the talent buttons, which sit at very high levels
    panel:EnableMouse(true)
    panel:Hide()
    T.Fill(panel, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(panel, "border")
    panel:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 6)
    panel.heads, panel.cards = {}, {}
    panel.off = CreateFrame("Button", nil, panel)
    panel.off:SetHeight(28)
    T.Fill(panel.off, "hover", "HIGHLIGHT"):SetAllPoints()
    panel.off.text = T.Text(panel.off, "label", "textDim")
    panel.off.text:SetPoint("LEFT", PAD, 0)
    panel:SetScript("OnHide", HideTip)
    panel:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not button:IsMouseOver() then self:Hide() end
    end)
    pcall(panel.RegisterEvent, panel, "GLOBAL_MOUSE_DOWN")
    return panel
end

function RouteMenu.Create(parent, width, columns, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 28)
    T.Fill(b, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Border(b, "border")
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.text = T.Text(b, "label", "text")
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetPoint("RIGHT", -24, 0)
    W.Chevron(b, "textDim", "up"):SetPoint("RIGHT", -10, 0)
    b.panel = Panel(b)
    function b:Refresh()
        local current, label = get(), ""
        local list = columns()
        if list.off[1] == current then label = list.off[2] end
        for _, column in ipairs(list) do
            for i = 2, #column do
                if column[i][1] == current then label = column[i].label end
            end
        end
        self.text:SetText(label)
    end
    b:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        if self.panel:IsShown() then return self.panel:Hide() end
        Fill(self.panel, columns(), get(), function(key)
            set(key)
            self:Refresh()
        end)
        self.panel:Show()
        T.FadeIn(self.panel, 0.12, 4)
    end)
    b:Refresh()
    return b
end
