--[[
  Tracker: one player position for the window and the compact map. It runs while one of them wants it and
  the player is inside an instance with a map; the Locator runs only then.
  Tracker.Want(who, on)  "window" / "overlay"
  Tracker.On(fn(state | false, id))  every TICK s while running; false: no position yet (Locator busy)
  Tracker.Running() -> instance map ID | nil;  Tracker.Locating() -> the Locator is looking
  state = Position's { x, y, facing, outside, room, level }
]]
local _, ns = ...
local Tracker = {}
ns.Tracker = Tracker

local TICK = 0.1
local wants, listeners = {}, {}
local pos

local driver = CreateFrame("Frame")
driver:Hide()

local function Stop()
    driver:Hide()
    if ns.Locator.IsRunning() then ns.Locator.Stop() end
    pos = nil
end

local function Update()
    local here = ns.Catalog.Here()
    if not (next(wants) and ns.Catalog.Has(here)) then return Stop() end
    if pos and pos.id == here then return end
    pos = ns.Position.New(here, ns.maps[here])
    if ns.Locator.Available() then ns.Locator.Start(here) end
    driver:Show()
end

function Tracker.Want(who, on)
    wants[who] = on or nil
    Update()
end

function Tracker.On(fn) listeners[#listeners + 1] = fn end
function Tracker.Running() return pos and pos.id or nil end
function Tracker.Locating() return ns.Locator.IsRunning() end

local wait = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    wait = wait + elapsed
    if wait < TICK or not pos then return end
    wait = 0
    local state = pos:Read() or false
    for _, fn in ipairs(listeners) do fn(state, pos.id) end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")  -- entering or leaving an instance
events:SetScript("OnEvent", function()
    Stop()
    Update()
end)
