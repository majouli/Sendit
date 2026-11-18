local _, ns = ...

local S = {}
ns.DribblerSession = S

local function Store()
    return ns.db and ns.db.dribbler
end

function S.Current()
    local d = Store()
    return d and d.session
end

function S.Active()
    local s = S.Current()
    return s ~= nil and s.active == true
end

function S.Start(money, now)
    local d = Store()
    if not d then return nil end
    d.session = {
        active = true, startMoney = money, started = now, spent = 0, disenchanted = 0,
        bought = {}, pending = {}, owned = {}, mats = {},
    }
    return d.session
end

function S.Stop(money, now)
    local s = S.Current()
    if not s or not s.active then return nil end
    s.active, s.endMoney, s.ended, s.pending = false, money, now, {}
    return s
end

function S.Pending(auctionID, offer)
    local s = S.Current()
    if not s or not s.active or not auctionID then return end
    s.pending[auctionID] = { id = offer.itemID, price = offer.buyout, link = offer.link }
end

function S.Completed(auctionID, now)
    local s = S.Current()
    local p = s and s.active and s.pending[auctionID]
    if not p then return nil end
    s.pending[auctionID] = nil
    s.spent = s.spent + p.price
    s.bought[#s.bought + 1] = { id = p.id, price = p.price, link = p.link, t = now }
    s.owned[p.id] = (s.owned[p.id] or 0) + 1
    return p
end

function S.Failed(auctionID)
    local s = S.Current()
    if s and s.pending then s.pending[auctionID] = nil end
end

function S.Owns(itemID)
    local s = S.Current()
    return s ~= nil and s.active and (s.owned[itemID] or 0) > 0
end

function S.OwnedCount()
    local s, n = S.Current(), 0
    for _, c in pairs(s and s.owned or {}) do n = n + c end
    return n
end

function S.Disenchanted(itemID, mats)
    local s = S.Current()
    if not s or not s.active then return end
    if itemID and (s.owned[itemID] or 0) > 0 then
        s.owned[itemID] = s.owned[itemID] - 1
        if s.owned[itemID] == 0 then s.owned[itemID] = nil end
    end
    s.disenchanted = s.disenchanted + 1
    for id, n in pairs(mats or {}) do
        if n > 0 then s.mats[id] = (s.mats[id] or 0) + n end
    end
end

function S.Summary(money, matPrice, itemValue, cut)
    local s = S.Current()
    if not s then return nil end
    local out = {
        active = s.active, startMoney = s.startMoney, money = s.active and money or s.endMoney or money,
        spent = s.spent, bought = #s.bought, disenchanted = s.disenchanted, mats = {}, matsValue = 0,
        left = 0, leftValue = 0, unpriced = false,
        duration = (s.ended or 0) > 0 and (s.ended - s.started) or nil,
    }
    out.change = out.money - s.startMoney
    for id, n in pairs(s.mats) do
        local price = matPrice(id)
        local value = price and math.floor(n * price * (1 - cut) + 0.5) or nil
        if not price then out.unpriced = true end
        out.mats[#out.mats + 1] = { id = id, count = n, value = value }
        out.matsValue = out.matsValue + (value or 0)
    end
    table.sort(out.mats, function(a, b)
        if (a.value or 0) ~= (b.value or 0) then return (a.value or 0) > (b.value or 0) end
        return a.id < b.id
    end)
    for id, n in pairs(s.owned) do
        out.left = out.left + n
        local v = itemValue(id)
        if v then out.leftValue = out.leftValue + n * v else out.unpriced = true end
    end
    out.income = out.matsValue + out.leftValue
    out.profit = out.income - out.spent
    return out
end
