--[[
  Pill: a toggle of the upgrade scan's filters - a tinted panel with an underline in its colour while
  on, dimmed text while off. color() -> r, g, b is read on every Set (theme changes).
  Pill.Create(parent, text, color, onClick, height) -> pill;  pill:Set(on);  pill:Natural() -> width for its text
]]
local _, ns = ...
local T = Sendit.Theme
local Pill = {}
ns.AuctionPill = Pill

Pill.HEIGHT = 24

function Pill.Create(parent, text, color, onClick, height)
    local p = CreateFrame("Button", nil, parent)
    p:SetHeight(height or Pill.HEIGHT)
    T.Fill(p, "panelAlt", "BACKGROUND"):SetAllPoints()
    p.tint = p:CreateTexture(nil, "BORDER")
    p.tint:SetAllPoints()
    p.line = p:CreateTexture(nil, "ARTWORK")
    p.line:SetPoint("BOTTOMLEFT")
    p.line:SetPoint("BOTTOMRIGHT")
    p.line:SetHeight(2)
    T.Fill(p, "hover", "HIGHLIGHT"):SetAllPoints()
    p.text = p:CreateFontString(nil, "OVERLAY")
    T.SetFont(p.text, 11)
    p.text:SetShadowOffset(1, -1)
    p.text:SetPoint("LEFT", 4, 1)
    p.text:SetPoint("RIGHT", -4, 1)
    p.text:SetWordWrap(false)
    p.text:SetText(text)
    function p:Set(on)
        local r, g, b = color()
        self.tint:SetColorTexture(r, g, b, 0.16)
        self.line:SetColorTexture(r, g, b, 1)
        self.text:SetTextColor(r, g, b, 1)
        self.tint:SetShown(on)
        self.line:SetShown(on)
        self.text:SetAlpha(on and 1 or 0.4)
    end
    function p:Natural() return math.ceil(self.text:GetStringWidth()) + 18 end
    p:SetScript("OnClick", onClick)
    return p
end
