--[[
  ItemRatings: rates items through Sendit Upgrade (Sendit.Service "upgrade"),
  reliably - each item once, however many quests / bosses give it. Shared by
  the modules (Quests' gear boost, Dungeons): Sendit.ItemRatings.New() makes
  one scanner with its own state; the module holds it.

  Sendit Upgrade needs the item's data in the client cache. The server sends
  uncached items slowly and drops mass requests: asking for all of them at
  once let most time out, and they were counted as "no upgrade" (seen in
  game: only items seen before showed up). Now items are requested in small
  batches, each item gets its own wait (WAIT seconds per request, asked again
  up to RETRIES times), and an item that never arrives counts as "not loaded"
  - never as "no upgrade". A few items per frame, so the game never stalls; a
  full scan may take a while.

  local Ratings = Sendit.ItemRatings.New()
  Ratings.Start(itemIDs, onProgress, onDone)   rate these (replaces a running scan)
  Ratings.Stop()
  Ratings.Get(itemID) -> rating, false (no upgrade / unusable / above your
                         level) or nil (not rated yet / not loaded)
  Ratings.Progress() -> rated, total, running, missing
      rated = answered items, missing = items the server never sent
  Ratings.Gated(itemID) -> the rating of an item that needs a higher level
      (gain for the character as it is now; rating.gate = its required level),
      for previews of higher content - Get never returns these
  Ratings.Why(itemID) -> why an item is not an upgrade (diagnostics, /sq boost):
      "missing" (never sent), "worse" (weaker than the worn item), "nogain"
      (rated, changes nothing for the spec), "gate" (needs a
      higher level), "error", or Upgrade's status ("unusable", "equipped" ...)
]]
local _, ns = ...
local PER_TICK, TICK, BATCH, WAIT, RETRIES = 8, 0.05, 20, 8, 3

local function Request(itemID)
    local api = C_Item or {}
    if api.RequestLoadItemDataByID then pcall(api.RequestLoadItemDataByID, itemID) end
end

local function Service() return ns.Service("upgrade") end

-- One scanner: its own queue and results (Quests and Dungeons scan apart).
local function New()
    local Ratings = {}
    local results, queue, waiting, why, gated = {}, {}, {}, {}, {}
    local total, rated, missing, ticker = 0, 0, 0, nil
    local onProgress, onDone

    local function Stop()
        if ticker then ticker:Cancel() ticker = nil end
    end
    Ratings.Stop = Stop

    local function Store(itemID, r)
        local gain = r.status == "ok" and type(r.pct) == "number" and r.pct > 0
        local rating = gain and { pct = r.pct, slotPct = r.slotPct, label = r.label, equipLoc = r.equipLoc,
            secondaryPct = r.secondaryPct, secondaryLabel = r.secondaryLabel, gate = r.gate }
        if gain and r.gate then gated[itemID] = rating end
        if gain and not r.gate then
            results[itemID] = rating
        else
            results[itemID] = false
            why[itemID] = r.status ~= "ok" and tostring(r.status) or r.gate and "gate"
                or (type(r.pct) == "number" and r.pct < 0) and "worse" or "nogain"
        end
        rated = rated + 1
    end

    -- Items on their way from the server: give up on one only after RETRIES
    -- requests of WAIT seconds each without an answer.
    local function Waiting(now)
        local count = 0
        for itemID, w in pairs(waiting) do
            count = count + 1
            if now - w.at >= WAIT then
                if w.tries >= RETRIES then
                    waiting[itemID] = nil
                    missing = missing + 1
                    why[itemID] = "missing"
                    count = count - 1
                else
                    w.tries, w.at = w.tries + 1, now
                    Request(itemID)
                end
            end
        end
        return count
    end

    local function Tick()
        local svc = Service()
        if not svc then Stop() return end
        local now = GetTime()
        local inFlight = Waiting(now)
        -- items asked for earlier: rate the ones that arrived
        for itemID in pairs(waiting) do
            local ok, r = pcall(svc.Rate, itemID)
            if not ok or type(r) ~= "table" then
                waiting[itemID] = nil
                results[itemID], why[itemID] = false, "error"
                rated = rated + 1
            elseif r.status ~= "loading" then
                waiting[itemID] = nil
                Store(itemID, r)
            end
        end
        local budget = PER_TICK
        while budget > 0 and #queue > 0 and inFlight < BATCH do
            local itemID = table.remove(queue, 1)
            budget = budget - 1
            local ok, r = pcall(svc.Rate, itemID)
            if not ok or type(r) ~= "table" then
                results[itemID], why[itemID] = false, "error"
                rated = rated + 1
            elseif r.status == "loading" then
                waiting[itemID] = { at = now, tries = 1 }
                Request(itemID)
                inFlight = inFlight + 1
            else
                Store(itemID, r)
            end
        end
        if #queue == 0 and next(waiting) == nil then
            Stop()
            if onDone then onDone() end
        elseif onProgress then
            onProgress()
        end
    end

    function Ratings.Start(itemIDs, progress, done)
        Stop()
        results, queue, waiting, why, gated, rated, missing = {}, {}, {}, {}, {}, 0, 0
        onProgress, onDone = progress, done
        local seen = {}
        for _, itemID in ipairs(itemIDs) do
            if type(itemID) == "number" and not seen[itemID] then
                seen[itemID] = true
                queue[#queue + 1] = itemID
            end
        end
        total = #queue
        if total == 0 then
            if onDone then onDone() end
            return
        end
        ticker = C_Timer.NewTicker(TICK, Tick)
        Tick()
    end

    function Ratings.Get(itemID) return results[itemID] end
    function Ratings.Why(itemID) return why[itemID] end
    function Ratings.Gated(itemID) return gated[itemID] end
    function Ratings.Progress() return rated, total, ticker ~= nil, missing end
    return Ratings
end

ns.ItemRatings = { New = New }
