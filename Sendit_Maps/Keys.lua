--[[
  Keys: inside a dungeon or raid with a map, the world map key (M) opens this map instead (profile mapKey).
  An override binding on our own button: the world map never opens there, so nothing has to hide it in
  combat. Override bindings cannot change in combat: a change then waits for its end.
]]
local _, ns = ...

local button = CreateFrame("Button", "SenditMapsKey", UIParent)
button:RegisterForClicks("AnyDown", "AnyUp")
-- the client clicks a bound button on key down, up or both, as it is set up: toggle once per press
button:SetScript("OnClick", function(self, _, down)
    if down then
        self.pressed = true
        ns.Window.Toggle()
    elseif self.pressed then
        self.pressed = false
    else
        ns.Window.Toggle()
    end
end)

local applied, pending = nil, false

local function Wanted()
    if not ns.module.profile or ns.module.profile.mapKey == false then return {} end
    local here = ns.Catalog.Here()
    if not ns.Catalog.Has(here) then return {} end
    return { GetBindingKey("TOGGLEWORLDMAP") }
end

local function Apply()
    if InCombatLockdown() then pending = true return end
    pending = false
    local keys = Wanted()
    local text = table.concat(keys, " ")
    if text == applied then return end
    applied = text
    ClearOverrideBindings(button)
    for _, key in ipairs(keys) do SetOverrideBindingClick(button, true, key, "SenditMapsKey") end
end
ns.ApplyKeys = Apply

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    Apply()
    -- an open window follows you into an instance
    if event == "PLAYER_ENTERING_WORLD" and ns.Window.Shown() then
        local here = ns.Catalog.Here()
        if ns.Catalog.Has(here) then ns.Window.Open(here) end
    end
end)
Sendit.OnSettingsChanged(Apply)
