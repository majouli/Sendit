--[[
  Live: keeps the auction data rated without the window - LOAD_DELAY s after login the newest data
  (own kept scan or web data, Scan.LoadLast) goes to Rank in the background; a finished scan at the
  auction house replaces it. The window only shows and filters.
  Live.Load() / ToggleScan() / Scanning() -> bool;  Live.OnChange(fn) (scan progress and new data)
  Live.Source() -> { at, auctions, web } of the data being shown | nil
]]
local _, ns = ...
local Scan, Rank = ns.AuctionScan, ns.AuctionRank
local Live = {}
ns.AuctionLive = Live

local LOAD_DELAY = 8
local listeners, source = {}, nil

local function Changed() for _, fn in ipairs(listeners) do fn() end end
function Live.OnChange(fn) listeners[#listeners + 1] = fn end

local function ScanChanged()
    local s = Scan.State()
    if s.phase == "done" and not s.ranked then
        s.ranked = true
        source = { at = s.at, auctions = s.auctions, web = s.web == true }
        Rank.Start(s.candidates)
    end
    Changed()
end

function Live.Source() return source end

function Live.Scanning()
    local phase = Scan.State().phase
    return phase == "loading" or phase == "reading" or phase == "items"
end

function Live.Load()
    if Live.Scanning() then return end
    Scan.LoadLast(ScanChanged)
end

function Live.ToggleScan()
    if Live.Scanning() then
        Scan.Stop()
        return Changed()
    end
    Scan.Start(ScanChanged)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(LOAD_DELAY, function()
        if Scan.State().phase == "idle" then Live.Load() end
    end)
end)
