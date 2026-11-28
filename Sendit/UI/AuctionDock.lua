--[[
  AuctionDock: the column of module buttons right of the auction house, top down by order, shown
  while it is open. Sendit.AuctionDock.Add{ name, order, icon, onClick, tooltip(GameTooltip) } -> button
  (button.dot = a status dot, hidden until the module shows it). Buttons carry a frame name because
  UI suites sweep unnamed frames beside Blizzard windows.
  Sendit.AuctionDock.Panel(frame): the modules' windows share the place beside the dock - showing one
  hides the others.
]]
local _, ns = ...
local T = ns.Theme
local Dock = {}
ns.AuctionDock = Dock

local SIZE, GAP, TOP = 40, 4, -64
local buttons, panels = {}, {}

local function AuctionFrame()
    local ah = _G["AuctionHouseFrame"]
    return ah and ah:IsShown() and ah or nil
end

function Dock.Layout()
    local ah = AuctionFrame()
    for i, b in ipairs(buttons) do
        b:ClearAllPoints()
        if ah then b:SetPoint("TOPLEFT", ah, "TOPRIGHT", 2, TOP - (i - 1) * (SIZE + GAP)) end
        b:SetShown(ah ~= nil)
    end
end

function Dock.Add(def)
    local b = CreateFrame("Button", def.name, UIParent)
    ns.ownFrames[b] = true
    b.order = def.order
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("HIGH")
    b:Hide()
    T.Fill(b, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(b, "border")
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 5, -5)
    b.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    b.icon:SetTexture(def.icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.dot = T.Circle(b, "success", 8, "OVERLAY")
    b.dot:SetPoint("TOPRIGHT", -2, -2)
    b.dot:Hide()
    b:SetScript("OnClick", def.onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        def.tooltip(GameTooltip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[#buttons + 1] = b
    table.sort(buttons, function(x, y) return x.order < y.order end)
    Dock.Layout()
    return b
end

function Dock.Panel(frame)
    panels[#panels + 1] = frame
    frame:HookScript("OnShow", function(self)
        if InCombatLockdown() then return end
        for _, p in ipairs(panels) do
            if p ~= self and p:IsShown() then p:Hide() end
        end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
-- next frame: the auction house UI handles both events after us
events:SetScript("OnEvent", function() C_Timer.After(0, Dock.Layout) end)
