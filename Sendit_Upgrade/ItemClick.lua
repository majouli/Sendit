--[[
  ItemClick: Alt-click on an item opens the compare window with it on the
  left and the equipped item of its slot on the right.

  One post-hook on Blizzard's HandleModifiedItemClick, the function every
  modified item click goes through in this client: bag slots
  (ContainerFrameItemButtonMixin:OnModifiedClick), chat item links
  (SetItemRef), the loot window, merchants - and Sendit Chat's loot cards,
  which call it too. hooksecurefunc runs after Blizzard's code and never
  changes it, so Shift (link), Ctrl (try on) and the rest stay as they are.
  Only Alt alone, only items that can be equipped.

  ItemClick.Handle(link)   (the hook; tests call it)
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
