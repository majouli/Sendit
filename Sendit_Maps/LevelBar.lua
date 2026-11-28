--[[
  LevelBar: a map's levels as a column on its right edge, like the floors of a lift - All on top, then
  1 .. n, each with a stripe in its level colour. The chosen level is filled, the player's level carries a
  dot. Hidden for one-level maps.
  LevelBar.Create(parent, onPick(level)) -> bar;  bar:Set(map, level, here[, noAll])  noAll: floors only
]]
local _, ns = ...
local T = Sendit.Theme
local L = ns.L
local LevelBar = {}
ns.LevelBar = LevelBar

local W, H, GAP = 38, 30, 4

local function Floor(bar, i)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(W, H)
    b.bg = T.Fill(b, "panelAlt", "BACKGROUND", 0, 0.9)
    b.bg:SetAllPoints()
    b.fill = T.Fill(b, "accent", "BACKGROUND", 1)
    b.fill:SetAllPoints()
    T.Border(b, "border")
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.stripe = b:CreateTexture(nil, "ARTWORK")
    b.stripe:SetPoint("TOPLEFT", 1, -1)
    b.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    b.stripe:SetWidth(3)
    b.text = T.Text(b, "label", "text")
    b.text:SetPoint("CENTER", 1, 0)
    b.here = T.Circle(b, "success", 6, "OVERLAY")
    b.here:SetPoint("TOPRIGHT", -4, -4)
    b:SetScript("OnClick", function(self) bar.onPick(self.level) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.level == 0 and L.all or L.levelTip:format(self.level), T.Color("text"))
        if self.isHere then GameTooltip:AddLine(L.here, T.Color("success")) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.floors[i] = b
    return b
end

local function Set(bar, map, level, here, noAll)
    local count = #map.levels
    bar:SetShown(count > 1)
    if count < 2 then return end
    local first = noAll and 1 or 0
    if bar.floors[0] then bar.floors[0]:SetShown(not noAll) end
    for i = first, count do
        local b = bar.floors[i] or Floor(bar, i)
        b.level, b.isHere = i, here == i
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", 0, -(i - first) * (H + GAP) - ((i > 0 and not noAll) and 6 or 0))  -- All stands apart
        local on = i == level
        b.fill:SetShown(on)
        T.Paint(b.text, on and "onAccent" or "text")
        b.text:SetText(i == 0 and L.all or tostring(i))
        local c = map.levels[i]
        b.stripe:SetShown(c ~= nil)
        if c then b.stripe:SetColorTexture(c[1], c[2], c[3], 1) end
        b.here:SetShown(here == i)
        b:Show()
    end
    for i = count + 1, #bar.floors do bar.floors[i]:Hide() end
    bar:SetSize(W, (count + 1) * (H + GAP) + 6)
end

function LevelBar.Create(parent, onPick)
    local bar = CreateFrame("Frame", nil, parent)
    bar.floors, bar.onPick, bar.Set = {}, onPick, Set
    bar:Hide()
    return bar
end
