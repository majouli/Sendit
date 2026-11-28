--[[
  Learn: looks the bundled data lacks (items new in Forever) learned from the auction data. Every listed
  item the catalog does not know is read from the client - slot, item class, look, quality, levels - and
  kept in Sendit_WardrobeDB.learned in the bundled format (Catalog.Add), so it shows with its auction price.
  Learn.Run() after login and on every window open: in the background, BUDGET ms a step, at most REQUESTS
  item loads a second (a request flood crashed the client); an item still without data WAIT s after each
  of TRIES requests waits for the next session.
  Learn.Restore() puts the kept items into the catalog (saved variables loaded)
  Learn.OnChange(fn) after looks were added
]]
local _, ns = ...
local Catalog, Slots = ns.Catalog, ns.Slots
local Learn = {}
ns.Learn = Learn

local BUDGET, STEP, REQUESTS, TRIES, WAIT, AFTER_LOGIN = 4, 0.05, 10, 3, 2, 10
local Clock = debugprofilestop or function() return 0 end
-- client equip location -> InventoryType (Data/Items.lua's slot numbers)
local INV = { INVTYPE_HEAD = 1, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_WEAPON = 13,
    INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17, INVTYPE_TABARD = 19,
    INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23,
    INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26 }

local listeners, queue, head, running = {}, {}, 1, false
local skip, tries = {}, {}  -- skip: not transmog gear (or no data), not read again this session
local second, asked, added = 0, 0, 0

function Learn.OnChange(fn) listeners[#listeners + 1] = fn end

local function Store()
    if not ns.store then return nil end
    ns.store.learned = type(ns.store.learned) == "table" and ns.store.learned or {}
    return ns.store.learned
end

function Learn.Restore()
    local kept = Store()
    for id, raw in pairs(kept or {}) do
        if ns.items[id] then kept[id] = nil  -- the bundled data has it now
        else Catalog.Add(id, raw) end
    end
end

-- asks the server for an item's data; false when this second's share is used up
local function Ask(id)
    local now = math.floor(GetTime())
    if now ~= second then second, asked = now, 0 end
    if asked >= REQUESTS then return false end
    asked = asked + 1
    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return true
end

-- "done" | "later" (data not there yet)
local function Read(id)
    if ns.items[id] or skip[id] then return "done" end
    local ok, _, _, _, equipLoc, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, id)
    if ok and equipLoc ~= nil then
        local inv = INV[equipLoc]
        if not inv or not Slots.Of(inv) then skip[id] = true return "done" end
    end
    local got, itemName, _, quality, itemLevel, minLevel = pcall(C_Item.GetItemInfo, id)
    local name = got and itemName or nil
    local look = ns.Read(C_TransmogCollection and C_TransmogCollection.GetItemInfo, id)
    if not (ok and equipLoc and name) then
        local t = tries[id]
        if t and GetTime() - t.at < WAIT then return "later" end  -- asked, the answer may still come
        if t and t.n >= TRIES then skip[id] = true return "done" end
        if Ask(id) then tries[id] = { at = GetTime(), n = (t and t.n or 0) + 1 } end
        return "later"
    end
    if type(look) ~= "number" or look == 0 then skip[id] = true return "done" end
    local raw = ("%d,%d,%d,%d,%d,0,1,%d|"):format(look, INV[equipLoc], (classID or 0) * 100 + (subclassID or 0),
        quality or 1, minLevel or 0, itemLevel or 0)
    local kept = Store()
    if kept then kept[id] = raw end
    Catalog.Add(id, raw)
    added = added + 1
    return "done"
end

local function Finish()
    running = false
    if added > 0 then
        added = 0
        for _, fn in ipairs(listeners) do pcall(fn) end
    end
end

local function Tick()
    local start, size, seen = Clock(), #queue - head + 1, 0
    while head <= #queue and seen < size and Clock() - start < BUDGET do
        local id = queue[head]
        queue[head], head, seen = nil, head + 1, seen + 1
        if Read(id) == "later" then queue[#queue + 1] = id end
    end
    if head > #queue then return Finish() end
    C_Timer.After(STEP, Tick)
end

function Learn.Run()
    if running then return end
    local prices = Sendit.Service("auctionPrices")
    if not (prices and prices.Ids) then return end
    queue, head, tries = {}, 1, {}
    for _, id in ipairs(prices.Ids()) do
        if not ns.items[id] and not skip[id] then queue[#queue + 1] = id end
    end
    if #queue == 0 then return end
    running = true
    C_Timer.After(0, Tick)
end

Sendit.OnReady(function() C_Timer.After(AFTER_LOGIN, Learn.Run) end)
