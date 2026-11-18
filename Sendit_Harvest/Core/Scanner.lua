local _, ns = ...
local L = ns.L

local S = {}
ns.Scanner = S

local STEP = 0.05
local BURST = 4
local SETTLE = 0.2
local TIMEOUT = 5
local PAUSE = 2
local RETRIES = 2
local RESCAN_AFTER = 600
local ABSENT_RECHECK = 3600

local AH = C_AuctionHouse
local Search = AH and AH.SendSearchQuery
local SORT = { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0,
                 reverseSort = false } }

local scan
local generation = 0

local Plain = ns.Plain

function S.Available()
    return Search ~= nil and AH.MakeItemKey ~= nil and AH.GetCommoditySearchResultInfo ~= nil
end

local function Absent(id, now)
    local t = ns.db and ns.db.absent[id]
    return t ~= nil and now - t < ABSENT_RECHECK
end

local function PriceItems()
    local list = ns.Loot.Items()
    for _, id in pairs(ns.Mats) do list[#list + 1] = id end
    return list
end

function S.Queue(now)
    local list = {}
    for _, id in ipairs(PriceItems()) do
        local price = ns.Prices.Get(id)
        local t = price and price.t or 0
        if now - t >= RESCAN_AFTER and not Absent(id, now) then list[#list + 1] = { id = id, t = t } end
    end
    table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.id < b.id
    end)
    for i, e in ipairs(list) do list[i] = e.id end
    return list
end

function S.AbsentCount(now)
    local n = 0
    for _, id in ipairs(PriceItems()) do
        if Absent(id, now) then n = n + 1 end
    end
    return n
end

local function Finish(result)
    if not scan then return end
    ns.db.lastScan = {
        t = scan.started, result = result, priced = scan.priced, total = scan.total,
        stats = scan.stats, secs = math.floor((GetTime() - scan.startedAt) * 10 + 0.5) / 10,
    }
    scan = nil
    generation = generation + 1
    ns.SettingsChanged()
end

local function Add(out, quantity, unit)
    if Plain(quantity) and Plain(unit) and quantity > 0 and unit > 0 then
        out[#out + 1] = { unit = unit, count = quantity }
    end
end

local function Read(id, key)
    local out = {}
    for i = 1, AH.GetNumCommoditySearchResults(id) or 0 do
        local r = AH.GetCommoditySearchResultInfo(id, i)
        if r then Add(out, r.quantity, r.unitPrice) end
    end
    if #out == 0 and AH.GetNumItemSearchResults then
        for i = 1, AH.GetNumItemSearchResults(key) or 0 do
            local r = AH.GetItemSearchResultInfo(key, i)
            if r and Plain(r.buyoutAmount) and Plain(r.quantity) and r.quantity > 0 then
                Add(out, r.quantity, r.buyoutAmount / r.quantity)
            end
        end
    end
    return out
end

local function Ready()
    return not AH.IsThrottledMessageSystemReady or AH.IsThrottledMessageSystemReady()
end

local function Resolve(id, p, answered)
    scan.pending[id] = nil
    local offers = answered and Read(id, p.key) or {}
    local outcome = not answered and "silent" or (#offers > 0 and "offers" or "empty")
    scan.stats[outcome] = scan.stats[outcome] + 1
    local price = ns.Prices.Robust(offers)
    if price then
        ns.Prices.Set(id, price, time())
        ns.db.absent[id] = nil
        scan.priced = scan.priced + 1
    elseif answered or scan.stats.dropped == 0 then
        ns.db.absent[id] = time()
    end
end

local function Tick()
    local now = GetTime()
    for _ = 1, BURST do
        local id = scan.queue[scan.next]
        if not id or now < scan.pausedUntil or not Ready() then break end
        local key = AH.MakeItemKey(id)
        scan.pending[id] = { key = key, sentAt = now }
        scan.next, scan.lastSent = scan.next + 1, id
        Search(key, SORT, false)
    end
    for pid, p in pairs(scan.pending) do
        if p.updateAt and now - p.updateAt >= SETTLE then
            Resolve(pid, p, true)
        elseif not p.updateAt and now - p.sentAt >= TIMEOUT then
            Resolve(pid, p, false)
        end
    end
    if not scan.queue[scan.next] and next(scan.pending) == nil then Finish("complete") end
end

local function Schedule(gen)
    C_Timer.After(STEP, function()
        if gen ~= generation or not scan then return end
        Tick()
        if gen == generation and scan then Schedule(gen) end
    end)
end

function S.IsScanning() return scan ~= nil end

function S.Start()
    if scan or not ns.db or not ns.Get("value") or not S.Available() then return end
    local queue = S.Queue(time())
    if #queue == 0 then return end
    generation = generation + 1
    scan = {
        queue = queue, total = #queue, next = 1, pending = {}, retries = {},
        priced = 0, pausedUntil = 0, started = time(), startedAt = GetTime(),
        stats = { offers = 0, empty = 0, silent = 0, dropped = 0 },
    }
    Schedule(generation)
end

local function Dropped()
    scan.stats.dropped = scan.stats.dropped + 1
    local id = scan.lastSent
    if not id or not scan.pending[id] then return end
    scan.pending[id] = nil
    if (scan.retries[id] or 0) < RETRIES then
        scan.retries[id] = (scan.retries[id] or 0) + 1
        table.insert(scan.queue, scan.next, id)
    end
end

local function Answered(id)
    local p = Plain(id) and scan.pending[id]
    if p then p.updateAt = GetTime() end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
                     "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "AUCTION_HOUSE_SHOW" then
        C_Timer.After(0, S.Start)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        Finish("closed")
    elseif not scan then
        return
    elseif event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
        Dropped()
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        Answered(arg)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" and type(arg) == "table" then
        Answered(arg.itemID)
    end
end)

if AH then
    for _, name in ipairs({ "SendBrowseQuery", "SendSearchQuery", "SendSellSearchQuery" }) do
        if AH[name] then
            hooksecurefunc(AH, name, function()
                if scan then scan.pausedUntil = GetTime() + PAUSE end
            end)
        end
    end
end

function S.Probe()
    local function has(v) return v and L.yes or L.no end
    local lines = {
        L.probeApis:format(has(Search), has(AH and AH.MakeItemKey),
            has(AH and AH.GetCommoditySearchResultInfo), has(AH and AH.GetItemSearchResultInfo),
            has(AH and AH.IsThrottledMessageSystemReady)),
        L.probePrices:format(ns.Prices.Count(), #S.Queue(math.huge), S.AbsentCount(time())),
    }
    local last = ns.db and ns.db.lastScan
    if last then
        lines[#lines + 1] = L.probeLast:format(ns.Prices.Age(time() - last.t),
            L["result_" .. last.result] or last.result, last.priced, last.total, last.secs)
        local st = last.stats or {}
        lines[#lines + 1] = L.probeStats:format(st.offers or 0, st.empty or 0, st.silent or 0, st.dropped or 0)
    else
        lines[#lines + 1] = L.probeNoScan
    end
    local profs = {}
    for _, prof in ipairs(ns.Professions.KEYS) do
        profs[#profs + 1] = L[prof] .. " "
            .. (ns.Professions.Knows(prof) and L.yes or L.no)
    end
    lines[#lines + 1] = L.probeProfessions:format(table.concat(profs, ", "))
    for _, line in ipairs(ns.Skinning.ProbeLines()) do lines[#lines + 1] = line end
    for _, line in ipairs(lines) do print("|cffb48cff" .. L.title .. ":|r " .. line) end
    return lines
end
