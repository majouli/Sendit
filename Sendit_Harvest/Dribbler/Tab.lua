local _, ns = ...
local L = ns.L

local Tab = {}
ns.DribblerTab = Tab

local button = Sendit.AuctionDock.Add({
    name = "SenditHarvestDribblerTab", order = 10, icon = "Interface\\Icons\\INV_Enchant_Disenchant",
    onClick = function() ns.DribblerWindow.Toggle() end,
    tooltip = function(tip)
        tip:SetText(L.dribTitle, 1, 1, 1, 1)
        tip:AddLine(ns.DribblerSession.Active() and L.dribRunning or L.dribSubtitle, 1, 1, 1, true)
    end,
})

function Tab.Refresh()
    button.dot:SetShown(ns.DribblerSession.Active())
end
