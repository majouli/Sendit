--[[
  Tab: side tab on the talent window's edge that folds the timeline in and out
  (LargeSideTabButtonTemplate; a plain Sendit tab if the template is missing). Named frame.
  Tab.Create(overlay, onClick) -> tab;  tab:SetOpen(open)
]]
local _, ns = ...
local L = ns.L
local T, W = Sendit.Theme, Sendit.Widgets

local Tab = {}
ns.Tab = Tab

local ICON = "Interface\\Icons\\INV_Misc_Map_01"

local function Blizzard(overlay, onClick)
    local ok, t = pcall(CreateFrame, "Frame", "SenditTalentsTab", overlay, "LargeSideTabButtonTemplate")
    if not ok or type(t) ~= "table" or type(t.Icon) ~= "table" or not t.SetCustomOnMouseUpHandler then return nil end
    if t.SetFillToInterior then t:SetFillToInterior(true) end
    t.Icon:SetTexture(ICON)
    t:SetChecked(false)
    t:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside then onClick() end
    end)
    function t:SetOpen(open) self:SetChecked(open) end
    return t
end

local function Plain(overlay, onClick)
    local t = CreateFrame("Button", "SenditTalentsTab", overlay)
    t:SetSize(24, 84)
    T.Fill(t, "bg", "BACKGROUND"):SetAllPoints()
    T.Border(t, "border")
    T.Fill(t, "hover", "HIGHLIGHT"):SetAllPoints()
    t.chevron = W.Chevron(t, "accent", "right")
    t.chevron:SetPoint("CENTER")
    t:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        onClick()
    end)
    function t:SetOpen(open) self.chevron:Point(open and "left" or "right") end
    return t
end

function Tab.Create(overlay, onClick)
    local t = Blizzard(overlay, onClick) or Plain(overlay, onClick)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sendit Talents", 1, 1, 1)
        GameTooltip:AddLine(L.toggle, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t:Hide()
    return t
end
