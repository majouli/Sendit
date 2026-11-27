--[[
  Collection: which looks the account has collected, from the client's transmog collection.
  Collection.Item(itemID) -> true (its look is collected) | false | nil (the client cannot tell)
  Collection.Look(look) -> true when any of its items is collected, false when none, nil unknown
  Collection.Count(itemIDs) -> collected looks, looks (each look counted once)
  Collection.OnChange(fn)   after the collection changed (cache cleared)
]]
local _, ns = ...
local Collection = {}
ns.Collection = Collection
local cache, listeners = {}, {}

local function Known(id)
    local api = C_TransmogCollection
    if not api then return nil end
    local _, source = ns.Read(api.GetItemInfo, id)
    if type(source) == "number" then
        local info = ns.Read(api.GetAppearanceInfoBySource, source)
        if type(info) == "table" and type(info.appearanceIsCollected) == "boolean" then
            return info.appearanceIsCollected
        end
        local has = ns.Read(api.PlayerHasTransmogItemModifiedAppearance, source)
        if type(has) == "boolean" then return has end
    end
    local has = ns.Read(api.PlayerHasTransmog, id)
    if type(has) == "boolean" then return has end
    return nil
end

function Collection.Item(id)
    local v = cache[id]
    if v == nil then
        v = Known(id)
        if v ~= nil then cache[id] = v end
    end
    return v
end

function Collection.Look(look)
    local unknown = false
    for _, id in ipairs(look.items) do
        local v = Collection.Item(id)
        if v then return true end
        if v == nil then unknown = true end
    end
    if unknown then return nil end
    return false
end

function Collection.Count(ids)
    local seen, have, total = {}, 0, 0
    for _, id in ipairs(ids) do
        local look = ns.Catalog.LookOf(id)
        if look and not seen[look] then
            seen[look] = true
            total = total + 1
            if Collection.Look(look) then have = have + 1 end
        end
    end
    return have, total
end

function Collection.OnChange(fn) listeners[#listeners + 1] = fn end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "TRANSMOG_COLLECTION_SOURCE_REMOVED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function()
    wipe(cache)
    for _, fn in ipairs(listeners) do fn() end
end)
