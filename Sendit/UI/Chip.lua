--[[
  Chip: the compact header button of the module windows (Quests, Dungeons) -
  label plus chevron, as wide as its text (capped at maxWidth). A chip whose
  filter narrows the list shows in gold, so an active filter is visible at a
  glance. Close: a small drawn X (no client glyph).

  Sendit.Widgets.Chip(parent, onClick, maxWidth) -> chip;  chip:SetLabel(text, active)
  Sendit.Widgets.Close(parent, onClick) -> button
]]
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local MAX = 220

function W.Chip(parent, onClick, maxWidth)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    T.Fill(b, "panelAlt", "BACKGROUND"):SetAllPoints()
    b.edges = T.Border(b, "border")
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.text = T.Text(b, "label", "text")
    b.text:SetPoint("LEFT", 10, 0)
    b.chevron = W.Chevron(b, "textDim")
    b.chevron:SetPoint("RIGHT", -10, 0)
    function b:SetLabel(text, active)
        self.text:SetText(text)
        local width = math.min(maxWidth or MAX, self.text:GetStringWidth() + 36)
        self.text:SetWidth(width - 36)
        self:SetWidth(width)
        T.Paint(self.text, active and "accent" or "text")
        for _, e in ipairs(self.edges) do T.Paint(e, active and "accent" or "border", active and 0.6 or nil) end
    end
    b:SetScript("OnClick", function(self) onClick(self) end)
    return b
end

function W.Close(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    local lines = {}
    for i, p in ipairs({ { 8, 8, 18, 18 }, { 18, 8, 8, 18 } }) do
        local line = b:CreateLine(nil, "ARTWORK")
        line:SetTexture(T.WHITE)
        line:SetThickness(1.5)
        line:SetStartPoint("TOPLEFT", b, p[1], -p[2])
        line:SetEndPoint("TOPLEFT", b, p[3], -p[4])
        T.Paint(line, "textDim")
        lines[i] = line
    end
    b:SetScript("OnEnter", function() for _, l in ipairs(lines) do T.Paint(l, "text") end end)
    b:SetScript("OnLeave", function() for _, l in ipairs(lines) do T.Paint(l, "textDim") end end)
    b:SetScript("OnClick", onClick)
    return b
end
