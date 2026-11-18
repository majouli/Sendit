--[[
  Rewards: fixed and pick-one items from the pinned reference (the client's
  own item lists replace them only for quests in the quest log - its calls
  answer 0 for any other quest), XP and money from the client's cached quest
  data. Missing values stay unknown.
  Aggregation deduplicates quests/items but preserves choice groups; branched
  components are explicitly catalogs, not an achievable payout promise.
]]
local _, ns = ...
local R = {}
ns.Rewards = R
local requested = {}
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil end
    return value
end
local function LiveItems(id, countFn, infoFn)
    local count = Read(countFn, id)
    if type(count) ~= "number" or type(infoFn) ~= "function" then return nil end
    -- Quest text can be cached before rewards. An unconfirmed zero must not
    -- erase the bundled items while the separate reward query is pending.
    if count == 0 and Read(_G["HaveQuestRewardData"], id) ~= true then return nil end
    local items = {}
    for index = 1, count do
        local ok, _, _, amount, _, _, itemID = pcall(infoFn, index, id)
        if not ok or (issecretvalue and (issecretvalue(amount) or issecretvalue(itemID)))
            or type(itemID) ~= "number" or type(amount) ~= "number" then return nil end
        items[#items + 1] = { itemId = itemID, amount = amount }
    end
    return items
end
function R.Get(id)
    local q = ns.quests[id]
    local reward = q and q.rewards or {}
    local money, items, choices, xp
    if Read(_G["HaveQuestData"], id) == true then
        xp = Read(_G["GetQuestLogRewardXP"], id)
        if type(xp) ~= "number" or xp < 0 then xp = nil end
        money = Read(_G["GetQuestLogRewardMoney"], id)
        if type(money) ~= "number" or money < 0 then money = nil end
        -- The client's item reward calls only know quests in the quest log; for
        -- any other quest they answer 0 (seen in game: quest 1053 lost its four
        -- choices). Outside the log the bundled reference stays.
        if ns.Progress.Log()[id] then
            items = LiveItems(id, _G["GetNumQuestLogRewards"], _G["GetQuestLogRewardInfo"])
            choices = LiveItems(id, _G["GetNumQuestLogChoices"], _G["GetQuestLogChoiceInfo"])
        end
    end
    if Read(_G["HaveQuestRewardData"], id) ~= true and not requested[id] then
        requested[id] = true
        if C_QuestLog and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, id) end
    end
    return { items = items or reward.items or {}, choices = choices or reward.choice or {}, money = money, xp = xp,
        known = q and q.rewards ~= nil }
end
function R.Chain(rows)
    local out = { items = {}, choices = {}, money = 0, xp = 0, missingXP = 0, missing = 0, branches = false }
    local seen, amounts, members = {}, {}, {}
    for _, row in ipairs(rows) do members[row.id] = true end
    for _, row in ipairs(rows) do
        local id = row.id
        if not seen[id] then
            seen[id] = true
            local r, q = R.Get(id), ns.quests[id]
            if r.xp == nil then out.missingXP = out.missingXP + 1 else out.xp = out.xp + r.xp end
            if r.money == nil then out.missing = out.missing + 1 else out.money = out.money + r.money end
            for _, item in ipairs(r.items) do amounts[item.itemId] = (amounts[item.itemId] or 0) + item.amount end
            if #r.choices > 0 then out.choices[#out.choices + 1] = { questID = id, items = r.choices } end
            if #ns.Database.Links(id, "after") > 1 then out.branches = true end
            for _, other in ipairs(q and q.exclusiveTo or {}) do if members[other] then out.branches = true end end
            if q and q.preQuestSingle and #q.preQuestSingle > 1 then out.branches = true end
        end
    end
    local ids = {}
    for id in pairs(amounts) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do out.items[#out.items + 1] = { itemId = id, amount = amounts[id] } end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    if count > 0 and out.missing == count then out.money = nil end
    if count > 0 and out.missingXP == count then out.xp = nil end
    return out
end
local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local queued
events:SetScript("OnEvent", function()
    if queued then return end
    queued = true
    C_Timer.After(0.1, function() queued = nil if ns.Window then ns.Window:Refresh() end end)
end)
