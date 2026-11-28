--[[
  Prices: the cheapest buyout per unit and the number listed of EVERY item in the auction house - not
  only gear - for other modules (service "auctionPrices": the sell advisor). Two sources: the in-game scan
  (Scan.lua adds every row it reads, own auctions excepted; kept in Sendit_UpgradeDB.auctionPrices) and the
  web data (Auction/Web.lua's lines, per unit). The newer is asked first, the other for what it lacks: the
  web data has no trade goods (cloth, herbs, ore - the API lists none on Forever), the scan has them.
  Prices.Begin() / Add(itemID, unitCopper, count) / Finish(at) while a scan reads;  Prices.Get(itemID) ->
  unit, count, at, web | nil;  Prices.At() -> at, web | nil;  Prices.Ids() -> { itemID, ... } of every
  listed item (both sources; the wardrobe learns looks its data lacks from them)
]]
local _, ns = ...
local Prices = {}
ns.AuctionPrices = Prices

local building
local webMap, webAt  -- the web data parsed once per file

function Prices.Begin() building = {} end

function Prices.Add(itemID, unit, count)
    if not building or not itemID or not unit or unit <= 0 then return end
    local e = building[itemID]
    if not e then
        building[itemID] = { u = unit, n = count or 1 }
    else
        if unit < e.u then e.u = unit end
        e.n = e.n + (count or 1)
    end
end

function Prices.Finish(at)
    if not building or not ns.db then return end
    ns.db.auctionPrices = { at = at, map = building }
    building = nil
end

function Prices.Drop() building = nil end

local function Web()
    local d = _G["SenditAuctionData"]
    if type(d) ~= "table" or type(d.items) ~= "string" or type(d.at) ~= "number" then return nil end
    if webAt ~= d.at then
        local map = {}
        for a, c, n in d.items:gmatch("(%d+):%-?%d+:[%d%.]*:(%d+):(%d+)") do
            local id, unit, count = tonumber(a) or 0, tonumber(c) or 0, tonumber(n) or 1
            local e = map[id]
            if not e then
                map[id] = { u = unit, n = count }
            else
                if unit < e.u then e.u = unit end
                e.n = e.n + count
            end
        end
        webMap, webAt = map, d.at
    end
    return webMap, webAt
end

-- the sources newest first: { { map, at, web } }
local function Sources()
    local list = {}
    local saved = ns.db and ns.db.auctionPrices
    local map, at = Web()
    if map then list[#list + 1] = { map, at, true } end
    if saved and type(saved.map) == "table" then list[#list + 1] = { saved.map, saved.at or 0, false } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    return list
end

function Prices.At()
    local newest = Sources()[1]
    if newest then return newest[2], newest[3] end
end

function Prices.Get(itemID)
    for _, src in ipairs(Sources()) do
        local e = src[1][itemID]
        if e then return e.u, e.n, src[2], src[3] end
    end
    return nil
end

function Prices.Ids()
    local seen, out = {}, {}
    for _, src in ipairs(Sources()) do
        for id in pairs(src[1]) do
            if not seen[id] then seen[id], out[#out + 1] = true, id end
        end
    end
    return out
end

Sendit.Provide("auctionPrices", { Get = Prices.Get, At = Prices.At, Ids = Prices.Ids })
