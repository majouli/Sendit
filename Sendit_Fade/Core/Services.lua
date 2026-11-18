--[[
  Services: whether the player is dealing with a service NPC (vendor, bank,
  flight master, trainer, ...), from events only.

  Two signs, because NPCs differ:
    - a service window is open (WINDOWS: open event -> close event); NPCs
      with one service (banker, vendor) open it without a gossip menu
    - the open gossip has menu options but no quests (flight master, guard
      directions, innkeeper); story gossip has quests or plain text only, and
      a quest greeting opens no gossip at all

  A close event can be lost (loading screen), so the open set is cleared on
  every PLAYER_ENTERING_WORLD.

  Services:IsServiceNPC()   -> true while either sign holds
  Services:OnWindowOpen(fn) -> fn() when a service window opens
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
local closes = {}  -- close event -> open event
for open, close in pairs(WINDOWS) do closes[close] = open end

local open = {}       -- open event -> true while that window is open
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

function Services:IsServiceNPC()
    return self:IsWindowOpen() or self:IsServiceGossip()
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
-- pcall: not every event exists in every client
for o, c in pairs(WINDOWS) do
    pcall(ev.RegisterEvent, ev, o)
    pcall(ev.RegisterEvent, ev, c)
end
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
