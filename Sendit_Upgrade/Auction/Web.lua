--[[
  Web: auction data from the optional Sendit_AuctionData addon, written by the Sendit auction data app
  (Sendit_Upgrade/Web, built as SenditAuctions.exe) from the Battle.net API (renewed hourly by the server).
  SenditAuctionData = { at = unix time, house = name, auctions = n, items = "id:suffix:bonuses:buyout:count"
  lines } (bonuses = sorted bonus ids "b1.b2" or empty; cheapest buyout per unit in copper - a stack's over
  its size - and the number of auctions per variant; one string because a Lua 5.1 chunk holds at most 2^18
  constants).
  The app adds interval (the server's renewal cadence, s) and every (its own look, s): Web.Timing() ->
  interval, every (an hour and 5 minutes for older files).
  Web.At() -> at, auctions | nil;  Web.Candidates() -> scan candidates (gear the character can wear),
  keyed like Scan.Key of the real link
]]
local _, ns = ...
local Slots, Wearable = Sendit.GearSlots, ns.AuctionWearable
local Web = {}
ns.AuctionWeb = Web

local function Data()
    local d = _G["SenditAuctionData"]
    if type(d) ~= "table" or type(d.items) ~= "string" or type(d.at) ~= "number" then return nil end
    return d
end

function Web.At()
    local d = Data()
    if not d then return nil end
    return d.at, d.auctions or 0
end

-- item string with the suffix (field 7) and the bonus ids (field 13 = their number)
local function Link(id, suffix, bonuses)
    if bonuses == "" then return ("item:%d::::::%d"):format(id, suffix) end
    local ids, dots = bonuses:gsub("%.", ":")
    return ("item:%d::::::%d::::::%d:%s"):format(id, suffix, dots + 1, ids)
end

function Web.Timing()
    local d = Data()
    return d and tonumber(d.interval) or 3600, d and tonumber(d.every) or 300
end

function Web.Candidates()
    local d, list = Data(), {}
    if not d then return list end
    for a, b, bonuses, c, n in d.items:gmatch("(%d+):(%-?%d+):([%d%.]*):(%d+):(%d+)") do
        local id, suffix, buyout, count = tonumber(a) or 0, tonumber(b), tonumber(c), tonumber(n)
        local _, _, _, equipLoc, icon = C_Item.GetItemInfoInstant(id)
        if Slots.Group(equipLoc) and buyout > 0 and Wearable.Can(id) then
            list[#list + 1] = {
                key = id .. ":" .. suffix .. (bonuses ~= "" and ":" .. bonuses or ""), itemID = id,
                link = Link(id, suffix, bonuses), buyout = buyout, icon = icon, equipLoc = equipLoc, count = count,
            }
        end
    end
    return list
end
