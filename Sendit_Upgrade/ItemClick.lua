--[[
  ItemClick: Alt-click on an equippable item opens the compare window with it left and the worn item
  right - one post-hook on HandleModifiedItemClick (bags, chat links, loot, merchants, Sendit Chat).
  ItemClick.Handle(link)
]]
local _, ns = ...

local ItemClick = {}
ns.ItemClick = ItemClick

local function Equippable(link)
    if type(link) ~= "string" or not link:find("|Hitem:", 1, true) then return false end
    local item = ns.Stats.Read(link)
    return item ~= nil and ns.Compare.SlotsFor(item) ~= nil
end

function ItemClick.Handle(link)
    if not (IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()) then return end
    if not Equippable(link) then return end
    ns.Window:Compare(link)
end

if type(_G["HandleModifiedItemClick"]) == "function" then
    hooksecurefunc("HandleModifiedItemClick", function(link) ItemClick.Handle(link) end)
end
