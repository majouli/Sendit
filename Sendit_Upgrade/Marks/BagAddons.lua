--[[
  BagAddons: the green upgrade arrows in bag addons that replace Blizzard's bags, through their public
  interfaces (we call them, they never call into our data):
  - Baganator: a corner widget (Baganator.API.RegisterCornerWidget; installed files API/Main.lua,
    2026-11-26) - it makes our arrow per button and asks onUpdate(corner, details) per item: true shows
    it, nil means "not known yet" (RequestItemButtonsRefresh redraws once the verdict is there).
    Default corner top right (the item level sits top left); players can move it in its settings.
  - EllesmereUI Bags: EUI_Bags.RegisterItemOverlayIcon(name, fn(button, data)) for every painted slot;
    its rule: no state on its secure button, our frames go on button._textOverlay.
]]
local _, ns = ...
local Arrow, Verdict = ns.Arrow, ns.Verdict

local WIDGET_ID, OVERLAY_NAME = "sendit_upgrade", "Sendit_Upgrade"
local done = {}

local function Baganator()
    local b = _G["Baganator"]
    local api = type(b) == "table" and b.API
    if done.baganator or type(api) ~= "table" or type(api.RegisterCornerWidget) ~= "function" then return end
    done.baganator = true
    api.RegisterCornerWidget(ns.L.arrowWidget or "Sendit Upgrade", WIDGET_ID,
        function(_, details)
            local link = details and details.itemLink
            if not link then return false end
            return Verdict.Of(link)
        end,
        function(button) return Arrow.Make(button) end,
        { corner = "top_right", priority = 1 })
    local function Refresh()
        if api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
    end
    Verdict.OnReady(Refresh)
    Verdict.OnReset(Refresh)
end

local function Ellesmere()
    local bags = _G["EUI_Bags"]
    if done.ellesmere or type(bags) ~= "table" or type(bags.RegisterItemOverlayIcon) ~= "function" then return end
    done.ellesmere = true
    bags.RegisterItemOverlayIcon(OVERLAY_NAME, function(button, data)
        local target = button and button._textOverlay
        if target then Arrow.Mark(target, data and data.itemLink or nil) end
    end)
end

local function Try()
    Baganator()
    Ellesmere()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", Try)
Try()
