--[[
  Scan: one read of the whole auction house (C_AuctionHouse.ReplicateItems) into candidates, READ rows
  per tick (at most BUDGET ms) so the game never stalls. A candidate = one item (id + suffix + bonus ids)
  with its cheapest buyout and the number of auctions. Kept: buyout gear the character can use
  (the row's "usable"), not its own auctions; the slot, quality and price filters apply when ranking,
  so they work on a kept scan too. A finished scan is kept in Sendit_UpgradeDB.auctionLast.
  Scan.Start(onChange) / Stop() / State() -> { phase, done, total, open, auctions, candidates, missing, at }
    phase "loading" | "reading" | "items" | "done" | "throttled" | "closed"; Scan.WaitMinutes()
  Scan.Last() -> at, auctions, web | nil;  Scan.LoadLast(onChange) -> the newer of the kept scan and the
    web data (Auction/Web.lua, state.web) as a finished scan
  Rules (a flood of item requests and link reads crashed the client on a 235k auction house):
  - a row's link is read only when the client has all its data (the row's hasAllInfo);
  - rows without: their item is asked for once per scan, at most REQUESTS per second, and only when
    the row passes the slot, quality and price filters; phase "items" then waits for the client
    (GET_ITEM_INFO_RECEIVED) until every row came, nothing arrived for QUIET s or ITEMS_MAX s passed;
  - the full read is shared by every addon once per COOLDOWN: any full read the client gets (also
    another addon's) starts it; until it ends the client's last answer is read again, else the kept
    scan is taken, and only without either it ends "throttled".
  Every row with a buyout also gives its unit price to Auction/Prices.lua (all items, not only gear).
]]
local _, ns = ...
local Slots, Filter, Web, Prices = Sendit.GearSlots, ns.AuctionFilter, ns.AuctionWeb, ns.AuctionPrices
local Scan = {}
ns.AuctionScan = Scan

local AH = C_AuctionHouse
local READ, BUDGET, STEP, SETTLE, TIMEOUT = 400, 4, 0.03, 1.0, 60  -- BUDGET: ms
local REQUESTS, QUIET, ITEMS_MAX, LOOK = 20, 8, 90, 0.5
local Clock = debugprofilestop or function() return 0 end
local COOLDOWN = 15 * 60
local isSecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not isSecret(v) end

local state = { phase = "idle", done = 0, total = 0, auctions = 0, candidates = {} }
local generation, onChange, byKey, me = 0, nil, {}, nil
local requested, requestSecond, requestCount = {}, 0, 0
local pending, arrivedAt, itemsFrom = {}, 0, 0
local pricedRows = {}  -- rows read again in phase "items" give their price once

local function Changed() if onChange then onChange() end end

function Scan.Available()
    return AH ~= nil and AH.ReplicateItems ~= nil and AH.GetNumReplicateItems ~= nil
end

function Scan.State() return state end

-- one candidate per variant: "id:suffix" or "id:suffix:b1.b2" (link field 7 = old random suffix,
-- field 13 = number of bonus ids, sorted; Forever's random suffixes are bonus ids); the unique id,
-- link level and modifiers are ignored
function Scan.Key(link)
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local f, n = {}, 0
    for v in (body .. ":"):gmatch("([^:]*):") do n = n + 1; f[n] = v end
    local id = tonumber(f[1])
    if not id then return nil end
    local key = id .. ":" .. (tonumber(f[7]) or 0)
    local bonuses = {}
    for i = 1, tonumber(f[13]) or 0 do bonuses[i] = tonumber(f[13 + i]) or 0 end
    if #bonuses == 0 then return key end
    table.sort(bonuses)
    return key .. ":" .. table.concat(bonuses, ".")
end

-- key -> itemID, suffix, bonus ids ("b1.b2" or "")
function Scan.Parts(key)
    local id, suffix, bonuses = key:match("^(%d+):(%-?%d+):?([%d%.]*)$")
    return tonumber(id), tonumber(suffix) or 0, bonuses or ""
end

local function LastAt() return ns.db and ns.db.auctionScanAt or 0 end

function Scan.WaitMinutes()
    return math.max(0, math.ceil((LastAt() + COOLDOWN - time()) / 60))
end

local function Request(itemID)
    if requested[itemID] then return end
    local second = math.floor(GetTime())
    if second ~= requestSecond then requestSecond, requestCount = second, 0 end
    if requestCount >= REQUESTS then return end
    requestCount = requestCount + 1
    requested[itemID] = true
    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
end

local function Add(link, itemID, buyout, icon, equipLoc, quality)
    local key = Scan.Key(link)
    if not key then return end
    local c = byKey[key]
    if not c then
        c = { key = key, itemID = itemID, link = link, buyout = buyout, icon = icon, equipLoc = equipLoc, count = 0 }
        byKey[key] = c
        state.candidates[#state.candidates + 1] = c
    elseif buyout < c.buyout then
        c.buyout, c.link = buyout, link
    end
    c.count = c.count + 1
    if Plain(quality) then c.quality = quality end
end

-- "ok" | "skip" | "later" (the client has not got the item's data yet)
local function Row(i)
    local ok, _, icon, count, quality, usable, _, _, _, _, buyout, _, _, _, owner, _, _, itemID, hasAll =
        pcall(AH.GetReplicateItemInfo, i)
    if not ok or not Plain(itemID) or type(itemID) ~= "number" then return "skip" end
    if not Plain(buyout) or type(buyout) ~= "number" or buyout <= 0 then return "skip" end
    if me and Plain(owner) and owner == me then return "skip" end
    local n = Plain(count) and type(count) == "number" and count > 0 and count or 1
    if not pricedRows[i] then
        pricedRows[i] = true
        Prices.Add(itemID, math.floor(buyout / n + 0.5), n)
    end
    if Plain(usable) and usable == false then return "skip" end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    if not Slots.Group(equipLoc) then return "skip" end
    if Plain(hasAll) and hasAll == false then
        if not Filter.Slot(equipLoc) or not Filter.Price(buyout) or not Filter.Type(itemID, equipLoc)
            or (Plain(quality) and not Filter.Quality(quality)) then return "skip" end
        Request(itemID)
        return "later"
    end
    local link = AH.GetReplicateItemLink(i)
    if not Plain(link) or type(link) ~= "string" then return "skip" end
    Add(link, itemID, buyout, icon, equipLoc, quality)
    return "ok"
end

local KEEP = { "key", "itemID", "link", "buyout", "icon", "equipLoc", "count", "quality" }

local function Copy(c)
    local out = {}
    for _, k in ipairs(KEEP) do out[k] = c[k] end
    return out
end

local function Keep()
    if not ns.db then return end
    local list = {}
    for i, c in ipairs(state.candidates) do list[i] = Copy(c) end
    ns.db.auctionLast = { at = state.at, auctions = state.auctions, candidates = list }
end

local function Finish(phase)
    state.phase = phase
    generation = generation + 1
    pending = {}
    if phase == "done" then
        Keep()
        Prices.Finish(state.at)
    else
        Prices.Drop()
    end
    Changed()
end

local function Kept()
    local last = ns.db and ns.db.auctionLast
    if last and last.candidates then return last end
end

function Scan.Last()
    local last, webAt, webAuctions = Kept(), Web.At()
    if webAt and (not last or webAt > (last.at or 0)) then return webAt, webAuctions, true end
    if last then return last.at, last.auctions, false end
end

function Scan.LoadLast(fn)
    local at, auctions, web = Scan.Last()
    if not at then return false end
    onChange = fn
    generation = generation + 1
    local list = {}
    if web then
        list = Web.Candidates()
    else
        for i, c in ipairs(Kept().candidates) do
            list[i] = Copy(c)
            list[i].key = type(c.link) == "string" and Scan.Key(c.link) or c.key
        end
    end
    state = { phase = "done", done = 0, total = 0, open = 0, auctions = auctions, candidates = list, missing = 0,
              at = at, kept = true, web = web }
    Changed()
    return true
end

local function Items(gen)
    if gen ~= generation then return end
    local left, start = {}, Clock()
    for n, i in ipairs(pending) do
        if Clock() - start > BUDGET then
            for k = n, #pending do left[#left + 1] = pending[k] end
            break
        end
        if Row(i) == "later" then left[#left + 1] = i end
    end
    local now = GetTime()
    if #left < #pending then arrivedAt = now end
    pending = left
    state.open = #pending
    if #pending == 0 or now - arrivedAt > QUIET or now - itemsFrom > ITEMS_MAX then
        state.missing = #pending
        return Finish("done")
    end
    Changed()
    C_Timer.After(LOOK, function() Items(gen) end)
end

local function Read(gen, total)
    local i = 0
    local function Tick()
        if gen ~= generation then return end
        local stop, start = math.min(total - 1, i + READ - 1), Clock()
        while i <= stop and Clock() - start <= BUDGET do
            if Row(i) == "later" then pending[#pending + 1] = i end
            i = i + 1
        end
        state.done = i
        Changed()
        if i < total then return C_Timer.After(STEP, Tick) end
        if #pending == 0 then return Finish("done") end
        itemsFrom = GetTime()
        state.phase, state.open, arrivedAt = "items", #pending, itemsFrom
        Changed()
        C_Timer.After(LOOK, function() Items(gen) end)
    end
    Tick()
end

local function ReadAll(gen)
    local n = AH.GetNumReplicateItems() or 0
    if not Plain(n) then n = 0 end
    local ok, name = pcall(UnitName, "player")
    me = ok and Plain(name) and name or nil
    pending = {}
    state.phase, state.done, state.total, state.auctions = "reading", 0, n, n
    Read(gen, n)
end

function Scan.Start(fn)
    onChange = fn
    if not Scan.Available() then return false end
    generation = generation + 1
    local gen = generation
    byKey, requested, pending, pricedRows = {}, {}, {}, {}
    Prices.Begin()
    state = { phase = "loading", done = 0, total = 0, open = 0, auctions = 0, candidates = {}, missing = 0, at = time() }
    if Scan.WaitMinutes() > 0 then
        if (AH.GetNumReplicateItems() or 0) > 0 then
            ReadAll(gen)
            Changed()
        elseif not Scan.LoadLast(fn) then
            Finish("throttled")
        end
        return true
    end
    if ns.db then ns.db.auctionScanAt = time() end
    AH.ReplicateItems()
    C_Timer.After(TIMEOUT, function()
        if gen ~= generation or state.phase ~= "loading" then return end
        if (AH.GetNumReplicateItems() or 0) > 0 then ReadAll(gen) else Finish("throttled") end
    end)
    Changed()
    return true
end

function Scan.Stop()
    generation = generation + 1
    pending = {}
    if state.phase == "loading" or state.phase == "reading" or state.phase == "items" then state.phase = "idle" end
    Changed()
end

local function Busy() return state.phase == "reading" or state.phase == "items" end

-- the list arrives in parts; reading starts once it has been quiet for SETTLE. A full read we did not
-- ask for (another addon's) still starts the shared cooldown.
local quietGen = 0
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "REPLICATE_ITEM_LIST_UPDATE")
pcall(events.RegisterEvent, events, "GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_CLOSED" then
        if state.phase == "loading" or Busy() then Finish("closed") end
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if state.phase == "items" then arrivedAt = GetTime() end
        return
    end
    if state.phase ~= "loading" then
        if not Busy() and ns.db and Scan.WaitMinutes() == 0 then ns.db.auctionScanAt = time() end
        return
    end
    quietGen = quietGen + 1
    local mine, gen = quietGen, generation
    C_Timer.After(SETTLE, function()
        if mine == quietGen and gen == generation and state.phase == "loading" then ReadAll(gen) end
    end)
end)
