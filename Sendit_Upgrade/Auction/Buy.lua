--[[
  Buy: buying a ranked candidate in two clicks. Buy.Find(c) looks for the cheapest buyout auction of the
  same variant (Scan.Key) under the item's search keys in turn: its exact key (item level, suffix), then
  the keys the server lists for the item's name (a browse search: variants with bonus ids have keys the
  item id alone does not reach), then the bare id; results that come in pages are read further first.
  Buy.Confirm(c) buys it at that price (PlaceBid needs the click). c.buy = nil | "searching" |
  "ready" (c.auctionID, c.price) | "buying" | "bought" | "gone". Buy.OnChange(fn).
  Closing the auction house drops every unfinished state (a found auction may be gone when it opens again).
  Buy.AtHouse() -> whether the auction house is open (buying and scanning need it).
]]
local _, ns = ...
local Scan = ns.AuctionScan
local Buy = {}
ns.AuctionBuy = Buy

local AH = C_AuctionHouse
local SETTLE, TIMEOUT, MORE = 0.3, 5, 4  -- MORE: result pages read further per key
local isSecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not isSecret(v) end
local listeners, pending, buying, open = {}, nil, nil, {}
local atHouse = false

local function Changed() for _, fn in ipairs(listeners) do fn() end end
function Buy.OnChange(fn) listeners[#listeners + 1] = fn end
function Buy.AtHouse() return atHouse end

local function Sorts()
    return { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }
end

local function AddKey(p, key)
    if type(key) ~= "table" then return end
    local id = tostring(key.itemID) .. ":" .. tostring(key.itemLevel) .. ":" .. tostring(key.itemSuffix)
    if p.seen[id] then return end
    p.seen[id] = true
    p.keys[#p.keys + 1] = key
end

local function Cheapest(c, key)
    local found
    for i = 1, AH.GetNumItemSearchResults(key) or 0 do
        local r = AH.GetItemSearchResultInfo(key, i)
        if r and Plain(r.buyoutAmount) and r.buyoutAmount > 0 and Plain(r.auctionID) and Plain(r.itemLink)
            and Scan.Key(r.itemLink) == c.key and not (Plain(r.containsOwnerItem) and r.containsOwnerItem)
            and (not found or r.buyoutAmount < found.buyoutAmount) then
            found = r
        end
    end
    return found
end

local Next

local function Wait(p, step)
    p.answeredAt, p.sentAt, p.step = nil, GetTime(), step
    C_Timer.After(TIMEOUT, function()
        if pending == p and p.step == step and not p.answeredAt and p.sentAt + TIMEOUT <= GetTime() then
            p.answeredAt = GetTime() - SETTLE
            if step == "browse" then Buy.Browsed() else Buy.Settle() end
        end
    end)
end

local function Send(p)
    p.key, p.more = p.keys[p.try], 0
    AH.SendSearchQuery(p.key, Sorts(), true)
    Wait(p, "search")
end

local function Browse(p)
    p.browsed = true
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(p.c.itemID) or C_Item.GetItemInfo(p.c.itemID)
    if not AH.SendBrowseQuery or not Plain(name) or type(name) ~= "string" then return Next(p) end
    AH.SendBrowseQuery({ searchString = name, sorts = Sorts(), filters = {}, itemClassFilters = {} })
    Wait(p, "browse")
end

function Next(p)
    if p.try < #p.keys then
        p.try = p.try + 1
        return Send(p)
    end
    if not p.browsed then return Browse(p) end
    if not p.plain then
        p.plain = true
        AddKey(p, AH.MakeItemKey(p.c.itemID))
        return Next(p)
    end
    pending = nil
    p.c.buy = "gone"
    Changed()
end

function Buy.Browsed()
    local p = pending
    if not p or p.step ~= "browse" then return end
    p.step = nil
    for _, r in ipairs(AH.GetBrowseResults and AH.GetBrowseResults() or {}) do
        local key = r.itemKey
        if type(key) == "table" and Plain(key.itemID) and key.itemID == p.c.itemID then AddKey(p, key) end
    end
    Next(p)
end

function Buy.Settle()
    local p = pending
    if not p or p.step ~= "search" or not p.answeredAt then return end
    local r = Cheapest(p.c, p.key)
    if r then
        pending = nil
        p.c.buy, p.c.auctionID, p.c.price = "ready", r.auctionID, r.buyoutAmount
        open[p.c] = true
        return Changed()
    end
    if p.more < MORE and AH.HasFullItemSearchResults and not AH.HasFullItemSearchResults(p.key)
        and AH.RequestMoreItemSearchResults then
        p.more = p.more + 1
        AH.RequestMoreItemSearchResults(p.key)
        return Wait(p, "search")
    end
    Next(p)
end

function Buy.Find(c)
    if pending or not atHouse or not AH or not AH.SendSearchQuery then return end
    c.buy, c.auctionID, c.price = "searching", nil, nil
    open[c] = true
    pending = { c = c, keys = {}, seen = {}, try = 0 }
    local _, suffix = Scan.Parts(c.key)
    local level = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(c.link)
    if (Plain(level) and level > 0) or suffix ~= 0 then
        AddKey(pending, AH.MakeItemKey(c.itemID, Plain(level) and level or 0, suffix))
    end
    Next(pending)
    Changed()
end

function Buy.Confirm(c)
    if c.buy ~= "ready" or not atHouse or GetMoney() < c.price then return end
    c.buy, buying = "buying", c
    AH.PlaceBid(c.auctionID, c.price)
    Changed()
end

local function Done(ok)
    local c = buying
    if not c then return end
    buying = nil
    c.buy = ok and "bought" or nil
    open[c] = nil
    Changed()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
                     "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SHOW_ERROR", "AUCTION_HOUSE_CLOSED",
                     "AUCTION_HOUSE_SHOW" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
        local p = pending
        if p and p.step == "search" and type(arg) == "table" and Plain(arg.itemID) and arg.itemID == p.c.itemID then
            p.answeredAt = GetTime()
            C_Timer.After(SETTLE, Buy.Settle)
        end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        local p = pending
        if p and p.step == "browse" and not p.answeredAt then
            p.answeredAt = GetTime()
            C_Timer.After(SETTLE, Buy.Browsed)
        end
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        if buying and Plain(arg) and arg == buying.auctionID then Done(true) end
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        Done(false)
    elseif event == "AUCTION_HOUSE_SHOW" then
        atHouse = true
        Changed()
    else
        atHouse = false
        for c in pairs(open) do
            if c.buy ~= "bought" and c.buy ~= "gone" then c.buy, c.auctionID, c.price = nil, nil, nil end
        end
        open, pending, buying = {}, nil, nil
        Changed()
    end
end)
