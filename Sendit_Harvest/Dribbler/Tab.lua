local _, ns = ...
local L = ns.L

local T = Sendit.Theme

local Tab = {}
ns.DribblerTab = Tab

local SIZE = 40
local button

local function Create()
    button = CreateFrame("Button", "SenditHarvestDribblerTab", UIParent)
    Sendit.ownFrames[button] = true
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("HIGH")
    T.Fill(button, "panel", "BACKGROUND"):SetAllPoints()
    button.edges = T.Border(button, "border")
    T.Fill(button, "hover", "HIGHLIGHT"):SetAllPoints()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 5, -5)
    button.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    button.icon:SetTexture("Interface\\Icons\\INV_Enchant_Disenchant")
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.dot = T.Circle(button, "success", 8, "OVERLAY")
    button.dot:SetPoint("TOPRIGHT", -2, -2)
    button:SetScript("OnClick", function() ns.DribblerWindow.Toggle() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.dribTitle, 1, 1, 1, 1)
        GameTooltip:AddLine(ns.DribblerSession.Active() and L.dribRunning or L.dribSubtitle, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local events = CreateFrame("Frame", nil, button)
    events:RegisterEvent("AUCTION_HOUSE_CLOSED")
    events:SetScript("OnEvent", function() button:Hide() end)
end

function Tab.Show()
    local ah = _G["AuctionHouseFrame"]
    if not ah or not ah:IsShown() then return end
    if not button then Create() end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", ah, "TOPRIGHT", 2, -64)
    button.dot:SetShown(ns.DribblerSession.Active())
    button:Show()
end

function Tab.Refresh()
    if button and button:IsShown() then button.dot:SetShown(ns.DribblerSession.Active()) end
end
