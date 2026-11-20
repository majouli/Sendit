--[[
  Hook: puts the route into Blizzard's talent window (PlayerSpellsFrame.TalentsFrame).
  One overlay frame of our own, redrawn after UpdateTreeCurrencyInfo and on TRAIT_CONFIG_UPDATED.
  Taint: hooksecurefunc only; Blizzard's frame is only read (getters) and anchored to.
  Inspecting someone else hides the route.
]]
local _, ns = ...
local Route, Tree, Markers, Picker = ns.Route, ns.Tree, ns.Markers, ns.Picker
local Call, Safe = ns.Call, ns.Safe

local talents, overlay, picker, pending

local function Method(name, ...)
    local fn = talents and talents[name]
    if type(fn) ~= "function" then return nil end
    return Call(fn, talents, ...)
end

local function Draw()
    pending = nil
    if not overlay then return end
    local configID = Method("GetConfigID")
    local _, class = UnitClass("player")
    class = Safe(class)
    local hide = ns.disabled or not configID or Method("IsInspecting") or #Route.ForClass(class) == 0
    picker:SetShown(not hide)
    Markers.Clear()
    if hide then return end
    local rankOf = Tree.RankOf(configID)
    local choice = ns.Choice(configID)
    local route = choice ~= "off" and (Route.Find(class, choice) or Route.Suggest(class, rankOf)) or nil
    local unspent, nodes = Tree.Unspent(configID), Tree.Nodes(configID)
    local plan = route and Route.Plan(route, rankOf, { nodes = nodes, open = Tree.Open(configID), free = unspent })
    local level = Safe(UnitLevel("player"))
    local reached = plan and plan.next and (type(level) ~= "number" or level >= plan.next.level)
    local ready = reached and (unspent == nil or unspent > 0)
    if plan then
        Markers.Draw(overlay, function(node) return Method("GetTalentButtonByNodeID", node) end,
            plan, nodes, rankOf, ready)
    end
    picker:Update({ class = class, configID = configID, route = route, plan = plan, rankOf = rankOf,
        reached = reached, ready = ready })
end

function ns.Refresh()
    if pending or not overlay then return end
    pending = true
    C_Timer.After(0, Draw)
end

local function Attach()
    talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if overlay or not talents then return end
    overlay = CreateFrame("Frame", "SenditTalentsOverlay", talents)
    overlay:SetAllPoints()
    overlay:SetFrameLevel((Call(talents.GetFrameLevel, talents) or 100) + 900)
    picker = Picker.Create(overlay, PlayerSpellsFrame, function()
        local configID = Method("GetConfigID")
        local choice = ns.Choice(configID)
        if choice then return choice end
        local _, class = UnitClass("player")
        local route = Route.Suggest(Safe(class), Tree.RankOf(configID))
        return route and route.key or "off"
    end, function(key)
        ns.SetChoice(Method("GetConfigID"), key)
        ns.Refresh()
    end)
    hooksecurefunc(talents, "UpdateTreeCurrencyInfo", ns.Refresh)
    overlay:SetScript("OnShow", ns.Refresh)
    ns.Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_PlayerSpells" then Attach() end
    else
        ns.Refresh()
    end
end)
if C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then Attach() end
