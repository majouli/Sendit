--[[
  Services: is the player dealing with a service NPC (vendor, bank, flight master ...)? From events: a
  service window is open, or the gossip has options but no quests. Cleared on PLAYER_ENTERING_WORLD.
  Services:OnWindowOpen(fn)
]]
local _, ns = ...

local Services = {}
ns.Services = Services

local WINDOWS = {
    MERCHANT_SHOW         = "MERCHANT_CLOSED",
    BANKFRAME_OPENED      = "BANKFRAME_CLOSED",
    TAXIMAP_OPENED        = "TAXIMAP_CLOSED",
    TRAINER_SHOW          = "TRAINER_CLOSED",
    AUCTION_HOUSE_SHOW    = "AUCTION_HOUSE_CLOSED",
    MAIL_SHOW             = "MAIL_CLOSED",
    PET_STABLE_SHOW       = "PET_STABLE_CLOSED",
    GUILDBANKFRAME_OPENED = "GUILDBANKFRAME_CLOSED",
}
local closes = {}
for open, close in pairs(WINDOWS) do closes[close] = open end

local open = {}
local listeners = {}

local function GossipCount(fn)
    local G = _G.C_GossipInfo
    local f = type(G) == "table" and G[fn]
    if type(f) ~= "function" then return 0 end
    local ok, v = pcall(f)
    v = ok and ns.Safe.Value(v)
    if type(v) == "table" then return #v end
    return type(v) == "number" and v or 0
end

function Services:IsWindowOpen()
    return next(open) ~= nil
end

function Services:IsServiceGossip()
    if GossipCount("GetNumAvailableQuests") + GossipCount("GetNumActiveQuests") > 0 then return false end
    return GossipCount("GetOptions") > 0
end

function Services:OnWindowOpen(fn)
    listeners[#listeners + 1] = fn
end

local ev = CreateFrame("Frame")
ns.ownFrames[ev] = true
ev:SetScript("OnEvent", function(_, event)
    if WINDOWS[event] then
        open[event] = true
        for _, fn in ipairs(listeners) do fn() end
    elseif closes[event] then
        open[closes[event]] = nil
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(open)
    end
end)
-- not every event exists in every client
for o, c in pairs(WINDOWS) do
    pcall(ev.RegisterEvent, ev, o)
    pcall(ev.RegisterEvent, ev, c)
end
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
