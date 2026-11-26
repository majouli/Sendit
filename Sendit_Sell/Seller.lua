--[[
  Seller: sells a list of bag slots to the open merchant, one every STEP seconds (the server takes one
  sale at a time). Before each sale the slot must still hold the same link - a moved or used item is
  skipped, never something else sold in its place. Stops when the merchant closes.
  More than BUYBACK items ask first: the merchant buys back only the last 12.
  Seller.Sell(list of { bag, slot, link, vendor }) / Busy() -> bool / Progress() -> done, total;
  Seller.OnChange(fn); Seller.BUYBACK
]]
local _, ns = ...
local Seller = {}
ns.Seller = Seller

local STEP = 0.2
Seller.BUYBACK = 12
local listeners, queue, done, earned, open = {}, nil, 0, 0, false

local function Changed() for _, fn in ipairs(listeners) do fn() end end
function Seller.OnChange(fn) listeners[#listeners + 1] = fn end
function Seller.Busy() return queue ~= nil end
function Seller.Progress() return done, queue and #queue or 0 end

local function Finish()
    if queue and done > 0 then
        Sendit.Print(ns.L.sold:format(done, ns.Money(earned)))
    end
    queue = nil
    Changed()
end

local function Step(index)
    if not queue or not open then return Finish() end
    local e = queue[index]
    if not e then return Finish() end
    if C_Container.GetContainerItemLink(e.bag, e.slot) == e.link then
        C_Container.UseContainerItem(e.bag, e.slot)
        done, earned = done + 1, earned + (e.vendor or 0)
    end
    Changed()
    C_Timer.After(STEP, function() Step(index + 1) end)
end

local function Start(list)
    queue, done, earned = list, 0, 0
    Changed()
    Step(1)
end

StaticPopupDialogs["SENDIT_SELL_MANY"] = {
    text = "%s", button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(_, data) Start(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function Seller.Sell(list)
    if queue or not open or #list == 0 then return end
    if #list > Seller.BUYBACK then
        StaticPopup_Show("SENDIT_SELL_MANY", ns.L.confirm:format(#list), nil, list)
        return
    end
    Start(list)
end

local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:SetScript("OnEvent", function(_, event)
    open = event == "MERCHANT_SHOW"
    if not open and queue then Finish() end
end)

function Seller.AtMerchant() return open end
