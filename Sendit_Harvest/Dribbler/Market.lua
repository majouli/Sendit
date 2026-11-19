local _, ns = ...

local M = {}
ns.DribblerMarket = M

local V, Session = ns.DribblerValue, ns.DribblerSession
local Plain = ns.Plain
local AH = C_AuctionHouse

local STEP = 0.1
local SEARCH_GAP = 0.6
local SETTLE = 0.2
local TIMEOUT = 5
local MAX_PAGES = 6
local MAX_RESOLVED = 30

local QUALITY_FILTERS = { "UncommonQuality", "RareQuality", "EpicQuality" }

local state = { offers = {}, byKey = {} }
local generation = 0
local listeners = {}
local sending = false
local isOpen = false

local function Changed()
    for _, fn in ipairs(listeners) do fn() end
end

function M.OnChange(fn) listeners[#listeners + 1] = fn end

function M.Available()
    return AH ~= nil and AH.SendBrowseQuery ~= nil and AH.GetBrowseResults ~= nil and AH.PlaceBid ~= nil
end

function M.IsOpen() return isOpen end
function M.Bracket() return state.bracket end
function M.Browsing() return state.browsing == true end
function M.Failed() return state.failed == true end

local function KeyString(key)
    return key.itemID .. ":" .. (key.itemLevel or 0) .. ":" .. (key.itemSuffix or 0)
end
M.KeyString = KeyString

local function Sorts()
    local order = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    return { { sortOrder = order, reverseSort = false } }
end

local function Filters()
    local out, enum = {}, Enum.AuctionHouseFilter or {}
    for _, name in ipairs(QUALITY_FILTERS) do
        if enum[name] then out[#out + 1] = enum[name] end
    end
    return out
end

local function Price(o)
    return o.buyout or o.minPrice or math.huge
end

local function Resolve(o)
    local key = o.key
    local id = key.itemID
    local _, _, _, equipLoc, icon, classID = C_Item.GetItemInfoInstant(id)
    local info = AH.GetItemKeyInfo and AH.GetItemKeyInfo(key)
    local name, link, quality, itemLevel, reqLevel = C_Item.GetItemInfo(id)
    if info then
        name = info.itemName or name
        quality = info.quality or quality
        icon = info.iconFileID or icon
    end
    if Plain(key.itemLevel) and key.itemLevel > 0 then itemLevel = key.itemLevel end
    if AH.GetItemKeyRequiredLevel then
        local r = AH.GetItemKeyRequiredLevel(key)
        if Plain(r) then reqLevel = r end
    end
    if not quality or not itemLevel or not classID then
        o.waiting = true
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return
    end
    o.waiting = nil
    o.itemID, o.name, o.icon, o.quality, o.itemLevel, o.reqLevel = id, name, icon, quality, itemLevel, reqLevel
    o.link = o.link or link
    local value, priced = V.Expected(id, quality, itemLevel, classID, equipLoc)
    o.value, o.priced = value, priced
    o.valid = value ~= nil and V.Contains(state.bracket, itemLevel) and state.classes[classID] == true
end

local function Ingest(results)
    for _, r in ipairs(results or {}) do
        local key = r.itemKey
        if key and Plain(key.itemID) and Plain(r.minPrice) and r.minPrice > 0 then
            local ks = KeyString(key)
            local o = state.byKey[ks]
            if not o then
                o = { key = key, ks = ks }
                state.byKey[ks] = o
                state.offers[#state.offers + 1] = o
            end
            o.minPrice = r.minPrice
            o.quantity = Plain(r.totalQuantity) and r.totalQuantity or nil
            Resolve(o)
        end
    end
end

function M.Offers()
    local out = {}
    for _, o in ipairs(state.offers) do
        if o.valid then out[#out + 1] = o end
    end
    table.sort(out, function(a, b)
        local x, y = M.Profit(a), M.Profit(b)
        if x ~= y then return x > y end
        x, y = Price(a), Price(b)
        if x ~= y then return x < y end
        return a.ks < b.ks
    end)
    return out
end

function M.Profit(o)
    if not o.value then return nil end
    return o.value - Price(o)
end

local function Ready()
    return not AH.IsThrottledMessageSystemReady or AH.IsThrottledMessageSystemReady()
end

local function NextToSearch()
    local n = 0
    for _, o in ipairs(M.Offers()) do
        n = n + 1
        if n > MAX_RESOLVED then return nil end
        if not o.searched and not o.searching then return o end
    end
    return nil
end

local function ReadAuctions(o)
    local best
    o.auctions = 0
    for i = 1, AH.GetNumItemSearchResults(o.key) or 0 do
        local r = AH.GetItemSearchResultInfo(o.key, i)
        if r and Plain(r.buyoutAmount) and r.buyoutAmount > 0 and Plain(r.auctionID)
            and not (Plain(r.containsOwnerItem) and r.containsOwnerItem) then
            o.auctions = o.auctions + 1
            if not best or r.buyoutAmount < best.buyoutAmount then best = r end
        end
    end
    o.searched, o.searching = true, nil
    if best then
        o.auctionID, o.buyout = best.auctionID, best.buyoutAmount
        if Plain(best.itemLink) and best.itemLink then o.link = best.itemLink end
    else
        o.auctionID, o.buyout, o.gone = nil, nil, true
    end
end

local function Tick(gen)
    if gen ~= generation or not isOpen then return end
    local now = GetTime()
    local s = state.search
    if s then
        if s.answeredAt and now - s.answeredAt >= SETTLE then
            ReadAuctions(s.offer)
            state.search, state.nextAt = nil, now + SEARCH_GAP
            Changed()
        elseif not s.answeredAt and now - s.sentAt >= TIMEOUT then
            s.offer.searching, state.search = nil, nil
            s.offer.searched = true
            state.nextAt = now + SEARCH_GAP
            Changed()
        end
    elseif not state.browsing and now >= (state.nextAt or 0) and Ready() then
        local o = NextToSearch()
        if o then
            o.searching = true
            state.search = { offer = o, sentAt = now }
            sending = true
            AH.SendSearchQuery(o.key, Sorts(), true)
            sending = false
        end
    end
    C_Timer.After(STEP, function() Tick(gen) end)
end

function M.Query(index, kind)
    if not isOpen or not M.Available() or not V.Bracket(index) then return false end
    generation = generation + 1
    state = { bracket = index, offers = {}, byKey = {}, browsing = true, pages = 0, classes = {} }
    local classFilters = {}
    for _, class in ipairs(V.Classes(kind)) do
        state.classes[class] = true
        classFilters[#classFilters + 1] = { classID = class }
    end
    local minLevel, maxLevel = V.QueryLevels(index)
    sending = true
    AH.SendBrowseQuery({
        searchString = "", sorts = Sorts(), minLevel = minLevel, maxLevel = maxLevel,
        filters = Filters(), itemClassFilters = classFilters,
    })
    sending = false
    local gen = generation
    C_Timer.After(STEP, function() Tick(gen) end)
    Changed()
    return true
end

function M.Refresh(o)
    if not o then return end
    o.searched, o.searching, o.gone = nil, nil, nil
    o.auctionID, o.buyout = nil, nil
    Changed()
end

function M.CanBuy(o)
    return o ~= nil and o.auctionID ~= nil and o.buyout ~= nil and not o.buying and Session.Active()
        and GetMoney() >= o.buyout
end

function M.BestDeal()
    for _, o in ipairs(M.Offers()) do
        local profit = M.Profit(o)
        if profit and profit > 0 and M.CanBuy(o) then return o end
    end
    return nil
end

function M.Buy(o)
    if not M.CanBuy(o) then return false end
    o.buying = true
    o.moneyBefore = GetMoney()
    state.buying = o
    Session.Pending(o.auctionID, o)
    AH.PlaceBid(o.auctionID, o.buyout)
    Changed()
    return true
end

local function OfferOfAuction(auctionID)
    for _, o in ipairs(state.offers) do
        if o.auctionID == auctionID then return o end
    end
end

local function Purchased(auctionID)
    if not Plain(auctionID) then return end
    Session.Completed(auctionID, time())
    local o = OfferOfAuction(auctionID)
    if o then
        o.buying = nil
        o.bought = (o.bought or 0) + 1
        M.Refresh(o)
    end
    if state.buying == o then state.buying = nil end
    Changed()
end

local function Paid(o)
    return o ~= nil and o.moneyBefore ~= nil and o.buyout ~= nil and GetMoney() <= o.moneyBefore - o.buyout
end

local function MoneyChanged()
    local o = state.buying
    if Paid(o) then Purchased(o.auctionID) end
end

local function BuyFailed()
    local o = state.buying
    if not o then return end
    if Paid(o) then return Purchased(o.auctionID) end
    state.buying = nil
    o.buying = nil
    Session.Failed(o.auctionID)
    M.Refresh(o)
end

local function ItemInfoArrived()
    local any = false
    for _, o in ipairs(state.offers) do
        if o.waiting then
            Resolve(o)
            any = true
        end
    end
    if any then Changed() end
end

local function BrowseUpdated()
    if not state.browsing then return end
    Ingest(AH.GetBrowseResults())
    if AH.HasFullBrowseResults and not AH.HasFullBrowseResults() and state.pages < MAX_PAGES
        and AH.RequestMoreBrowseResults then
        state.pages = state.pages + 1
        AH.RequestMoreBrowseResults()
    else
        state.browsing = false
    end
    Changed()
end

local function SearchAnswered(key)
    local s = state.search
    if s and type(key) == "table" and Plain(key.itemID) and KeyString(key) == s.offer.ks then
        s.answeredAt = GetTime()
    end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
                     "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_FAILURE",
                     "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
                     "AUCTION_HOUSE_SHOW_ERROR", "GET_ITEM_INFO_RECEIVED", "ITEM_KEY_ITEM_INFO_RECEIVED",
                     "PLAYER_MONEY" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "AUCTION_HOUSE_SHOW" then
        isOpen = true
        Changed()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        isOpen = false
        generation = generation + 1
        state = { offers = {}, byKey = {} }
        Changed()
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        BrowseUpdated()
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        if state.browsing then state.browsing, state.failed = false, true end
        Changed()
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        SearchAnswered(arg)
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        Purchased(arg)
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        BuyFailed()
    elseif event == "PLAYER_MONEY" then
        MoneyChanged()
    else
        ItemInfoArrived()
    end
end)

if AH and AH.SendBrowseQuery then
    hooksecurefunc(AH, "SendBrowseQuery", function()
        if not sending and state.browsing then
            state.browsing = false
            Changed()
        end
    end)
end
