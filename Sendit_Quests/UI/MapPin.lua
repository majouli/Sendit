--[[
  MapPin: Sendit's own marker on the world map for a tracked quest station -
  the journal's book in a gold ring, tooltip with the quest and what to do
  there (pick up / objective / turn in), right click removes it.

  Taint-free by construction: the pin and its watcher are our own frames,
  children of the map canvas (WorldMapFrame:GetCanvas()); nothing of Blizzard's
  is hooked or written. The watcher's OnUpdate (runs only while the map is
  open) shows the pin when the map shows its UiMap and keeps it at its spot
  and size through zooming. Opening the map from addon code only out of
  combat.

  MapPin.Set(uiMapID, x, y, questID, kind)   kind "g" giver | "f" turn-in | "t" objective
  MapPin.Show()   open the world map on the pin's map (out of combat)
  MapPin.Clear() / MapPin.Get() -> target or nil
]]
local _, ns = ...
local T = Sendit.Theme
local MapPin = {}
ns.MapPin = MapPin
local SIZE = 26
local target, pin, watcher

local function Canvas()
    local map = _G["WorldMapFrame"]
    local ok, canvas = pcall(function() return map and map.GetCanvas and map:GetCanvas() end)
    return ok and canvas or nil, map
end

local function Place()
    local canvas, map = Canvas()
    if not (pin and canvas and target) then return end
    local ok, mapID = pcall(map.GetMapID, map)
    if not ok or mapID ~= target.map then pin:Hide() return end
    local okScale, scale = pcall(map.GetCanvasScale, map)
    pin:SetScale(1 / ((okScale and type(scale) == "number" and scale > 0) and scale or 1))
    local s = pin:GetScale()
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * target.x / s, -canvas:GetHeight() * target.y / s)
    pin:Show()
end

local KIND = { g = "pinGiver", f = "pinTurnIn", t = "pinTarget" }

local function Build()
    local canvas = Canvas()
    if not canvas or pin then return pin ~= nil end
    pin = CreateFrame("Button", "SenditQuestsMapPin", canvas)
    pin:SetSize(SIZE, SIZE)
    pin:SetFrameLevel(canvas:GetFrameLevel() + 2000)
    pin:RegisterForClicks("RightButtonUp")
    local ring = T.Circle(pin, "accent", SIZE, "BACKGROUND", 0)
    ring:SetPoint("CENTER")
    T.Circle(pin, "bg", SIZE - 4, "BACKGROUND", 1):SetPoint("CENTER")
    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetSize(SIZE - 8, SIZE - 8)
    icon:SetPoint("CENTER")
    T.RoundOff(icon)
    pin:SetScript("OnEnter", function(self)
        if not target then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.Database.Name(target.quest), 1, 0.82, 0)
        GameTooltip:AddLine(ns.L[KIND[target.kind] or "pinGiver"], 1, 1, 1)
        GameTooltip:AddLine("Sendit Quests · " .. ns.L.pinClear, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", function() MapPin.Clear() GameTooltip:Hide() end)
    pin:Hide()
    watcher = CreateFrame("Frame", nil, canvas)
    watcher:SetSize(1, 1)
    local wait = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.1
        Place()
    end)
    return true
end

function MapPin.Set(map, x, y, questID, kind)
    target = { map = map, x = x, y = y, quest = questID, kind = kind }
    if Build() then Place() end
    return true
end

function MapPin.Get() return target end

function MapPin.Clear()
    target = nil
    if pin then pin:Hide() end
end

function MapPin.Show()
    if not target or InCombatLockdown() then return false end
    local map = _G["WorldMapFrame"]
    local open = _G["OpenWorldMap"]
    local ok
    if map and map:IsShown() and map.SetMapID then
        ok = pcall(map.SetMapID, map, target.map)
    elseif type(open) == "function" then
        ok = pcall(open, target.map)
    end
    if Build() then Place() end
    return ok == true
end
