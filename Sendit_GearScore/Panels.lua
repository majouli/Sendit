--[[
  Panels: GearScore on the character and inspect windows.
  Character window: our own row above Blizzard's stats list, which is moved down one row with
  SetPoint (no Lua state of Blizzard's written); the row copies a shown row's font and colours.
  Never through PAPERDOLL_STATCATEGORIES / STATINFO: Blizzard calling our code taints the window
  (secret health then fails). Rule: Blizzard code must never call or read anything of ours.
  Inspect window: "GS N" at inspectPos ("top" above the level line, "bottom" under the slots).
  All frames are named children of Blizzard frames; nothing hooked, no fields written.
]]
local _, ns = ...
local L = ns.L
local Score, Inspect = ns.Score, ns.Inspect

local Panels = {}
ns.Panels = Panels

local function FirstFrame(...)
    for i = 1, select("#", ...) do
        local f = _G[select(i, ...)]
        if f then return f end
    end
end

-- Blizzard's list box anchors (CharacterStatsPaneScrollBoxTemplate): TOPLEFT 10, -8
local LIST_LEFT, LIST_TOP = 10, -8
local ROW_HEIGHT = 26

local row
local function RefreshRow()
    if not row then return end
    local entry = Inspect.Get(ns.GUID("player"))
    row.value:SetText(entry and Score.Colored(entry.score) or "-")
end

local function CopyStyle(list)
    local box = list.ScrollBox
    if not (box and box.ForEachFrame) then return end
    pcall(box.ForEachFrame, box, function(frame, data)
        if row.styled or type(data) ~= "table" or data.isHeader or not frame.Label or not frame.Value then return end
        local ok1, font, size, flags = pcall(frame.Label.GetFont, frame.Label)
        local ok2, vfont, vsize, vflags = pcall(frame.Value.GetFont, frame.Value)
        local ok3, r, g, b, a = pcall(frame.Label.GetTextColor, frame.Label)
        font, size, vfont, vsize = ns.Safe(font), ns.Safe(size), ns.Safe(vfont), ns.Safe(vsize)
        if not (ok1 and ok2 and font and size and vfont and vsize) then return end
        row.label:SetFont(font, size, ns.Safe(flags) or "")
        row.value:SetFont(vfont, vsize, ns.Safe(vflags) or "")
        r, g, b, a = ns.Safe(r), ns.Safe(g), ns.Safe(b), ns.Safe(a)
        if ok3 and r and g and b then row.label:SetTextColor(r, g, b, a or 1) end
        row.styled = true
    end)
end

function Panels.BuildStatRow()
    local list = FirstFrame("CharacterStatsPaneScrollBox")
    if not list or row then return false end
    local box = list.ScrollBox
    row = CreateFrame("Frame", "SenditGearScoreRow", list)
    row.list, row.box = list, box
    row:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_LEFT, LIST_TOP)
    if box then
        row:SetPoint("RIGHT", box, "RIGHT", 0, 0)
    else
        row:SetPoint("RIGHT", list, "RIGHT", -30, 0)
    end
    row:SetHeight(ROW_HEIGHT)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 11, 0)
    row.label:SetText((_G["STAT_FORMAT"] or "%s:"):format(L.gearScore))
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("RIGHT", -8, 0)
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.06)
    divider:SetPoint("BOTTOMLEFT", 8, 0)
    divider:SetPoint("BOTTOMRIGHT", -8, 0)
    divider:SetHeight(1)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        local entry = Inspect.Get(ns.GUID("player"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.gearScore .. " " .. (entry and entry.score or "-"), 1, 1, 1)
        if entry then GameTooltip:AddLine(L.avgItemLevel:format(entry.ilvl), 1, 0.82, 0) end
        GameTooltip:AddLine(L.statTooltip, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnShow", function()
        RefreshRow()
        if not row.styled then C_Timer.After(0, function() CopyStyle(list) end) end
    end)
    RefreshRow()
    Panels.Apply()
    return true
end

local LEVEL_GAP, SLOT_GAP = 2, -8

local badge
local function InspectedGuid()
    local frame = FirstFrame("InspectFrame")
    local unit = frame and frame.unit
    return unit and ns.GUID(unit)
end

local function RefreshBadge()
    if not badge then return end
    local entry = Inspect.Get(InspectedGuid())
    badge.text:SetText(L.gsShort .. " " .. (entry and Score.Colored(entry.score) or "|cff999999-|r"))
    badge:SetWidth(badge.text:GetStringWidth() + 4)
end

local function BuildInspect()
    local inspect = FirstFrame("InspectFrame")
    local doll = FirstFrame("InspectPaperDollFrame") or inspect
    if not doll or badge then return end
    badge = CreateFrame("Frame", "SenditGearScoreBadge", doll)
    badge.doll = doll
    badge:SetHeight(14)
    badge:SetFrameLevel(doll:GetFrameLevel() + 20)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badge.text:SetPoint("CENTER")
    badge:EnableMouse(true)
    badge:SetScript("OnEnter", function(self)
        local entry = Inspect.Get(InspectedGuid())
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.gearScore .. " " .. entry.score, 1, 1, 1)
        GameTooltip:AddLine(L.avgItemLevel:format(entry.ilvl), 1, 0.82, 0)
        GameTooltip:Show()
    end)
    badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    badge:SetScript("OnShow", RefreshBadge)
    RefreshBadge()
    Panels.Apply()
    if ns.TalentView then ns.TalentView.Attach() end
end

function Panels.Apply()
    local db = ns.db or {}
    if row then
        row:SetShown(db.charRow ~= false)
        if row.box then
            local shift = row:IsShown() and ROW_HEIGHT or 0
            row.box:SetPoint("TOPLEFT", row.list, "TOPLEFT", LIST_LEFT, LIST_TOP - shift)
        end
    end
    if badge then
        badge:ClearAllPoints()
        local level, slot = FirstFrame("InspectLevelText"), FirstFrame("InspectTrinket1Slot")
        if db.inspectPos == "bottom" and slot then
            badge:SetPoint("TOP", slot, "BOTTOM", 0, SLOT_GAP)
        elseif level then
            badge:SetPoint("BOTTOM", level, "TOP", 0, LEVEL_GAP)
        else
            badge:SetPoint("TOP", badge.doll, "TOP", 0, -30)
        end
    end
end

Inspect.OnChange(function(guid)
    if badge and guid == InspectedGuid() then RefreshBadge() end
    if row and guid == ns.GUID("player") then RefreshRow() end
end)

ns.On("ADDON_LOADED", function(name)
    if name == "Blizzard_InspectUI" then BuildInspect() end
end)
ns.On("PLAYER_LOGIN", function()
    Panels.BuildStatRow()
    if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then BuildInspect() end
end)
