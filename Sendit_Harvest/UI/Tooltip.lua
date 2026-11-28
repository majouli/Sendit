local _, ns = ...
local L = ns.L

local FALLBACK_ICON = 134400
local ACCENT = "|cffb48cff"
local DIM = "|cff999999"
local NEUTRAL = "|cffffffff"
local KIND_COLOR = {
    dust = "|cffffffff", essence = "|cff1eff00", shard = "|cff0070dd", crystal = "|cffa335ee",
}
local QUALITY_COLOR = {
    [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee",
}

local Plain = ns.Plain

local function Amount(r)
    if r.min == r.max then return r.min .. "x" end
    return r.min .. "-" .. r.max .. "x"
end

local function ChanceText(c)
    if c >= 1 then return "100%" end
    if c < 0.01 then return "<1%" end
    return ("%d%%"):format(math.floor(c * 100 + 0.5))
end

local function MatName(item)
    local name = ns.ItemName(item)
    if name then return name end
    name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
    if Plain(name) and name ~= "" then return name end
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
    return "?"
end

local function MatText(r, withName)
    local icon = C_Item.GetItemIconByID(r.item) or FALLBACK_ICON
    local text = ("|T%s:0|t %s"):format(icon, Amount(r))
    if withName then
        local color = KIND_COLOR[r.kind] or QUALITY_COLOR[r.quality] or ""
        text = text .. " " .. color .. MatName(r.item) .. "|r"
    end
    return text
end

local function MatDetail(r, chances, value)
    local parts = {}
    if chances then parts[#parts + 1] = DIM .. ChanceText(r.chance) .. "|r" end
    if value then
        local price = ns.Prices.Get(r.item)
        parts[#parts + 1] = price and (NEUTRAL .. ns.Prices.Money(price.p) .. "|r") or (DIM .. "?|r")
    end
    return table.concat(parts, "  ")
end

local function AddYieldLines(tooltip, label, note, results)
    local names, chances, value = ns.Get("names"), ns.Get("chances"), ns.Get("value")
    local header = ACCENT .. label .. ":|r" .. (note and (" " .. DIM .. note .. "|r") or "")
    if ns.Get("compact") then
        local parts = {}
        for _, r in ipairs(results) do
            local detail = MatDetail(r, chances, value)
            parts[#parts + 1] = MatText(r, names) .. (detail ~= "" and (" " .. detail) or "")
        end
        tooltip:AddLine(header .. " " .. table.concat(parts, "  "))
    else
        tooltip:AddLine(header)
        for _, r in ipairs(results) do
            tooltip:AddDoubleLine("  " .. MatText(r, names), MatDetail(r, chances, value),
                1, 1, 1, 0.6, 0.6, 0.6)
        end
    end
end

local function Wanted(prof)
    if not ns.Get("enabled") or not ns.Get(prof) then return false end
    if ns.Get("shiftOnly") and not IsShiftKeyDown() then return false end
    if ns.Get("onlyKnown") and not ns.Professions.Knows(prof) then return false end
    return true
end

local function AddDisenchant(tooltip, item)
    if not Plain(item) or not Wanted("disenchant") then return end
    local results = ns.Disenchant.ForItem(item)
    if results and #results > 0 then
        AddYieldLines(tooltip, L.disenchant, nil, results)
    end
end

local function AddSkinning(tooltip, unit, guid, title)
    if not Wanted("skinning") then return end
    local results, info = ns.Skinning.ForUnit(unit, guid, title)
    if not results or #results == 0 then return end
    local notes = {}
    if info.skill then notes[#notes + 1] = L.skillNeeded:format(info.skill) end
    if info.source == "level" then notes[#notes + 1] = L.byLevel end
    AddYieldLines(tooltip, L.skinning, #notes > 0 and table.concat(notes, ", ") or nil, results)
end

local function Title(data)
    local line = data and type(data.lines) == "table" and data.lines[1]
    local text = line and line.leftText
    return Plain(text) and text or nil
end

local function AddNode(tooltip, data)
    local results, info = ns.Gathering.Find(ns.Gathering.ObjectID(data and data.guid), Title(data))
    if not results or not Wanted(info.prof) then return end
    local note = L.skillNeeded:format(info.skill)
    if info.maxUses > 1 then
        local uses = info.minUses == info.maxUses and tostring(info.minUses) or (info.minUses .. "-" .. info.maxUses)
        note = note .. ", " .. L.uses:format(uses)
    end
    AddYieldLines(tooltip, L[info.prof], note, results)
end

local function TooltipUnit(tooltip)
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if ok and Plain(unit) then return unit end
    return "mouseover"
end

local T = Enum.TooltipDataType
TooltipDataProcessor.AddTooltipPostCall(T.Item, function(tooltip, data)
    AddDisenchant(tooltip, data and data.id)
end)
TooltipDataProcessor.AddTooltipPostCall(T.Unit, function(tooltip, data)
    AddSkinning(tooltip, TooltipUnit(tooltip), data and data.guid, Title(data))
end)
TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes or T.Object, function(tooltip, data)
    local kind = data and data.type
    if Plain(kind) and (kind == T.Item or kind == T.Unit) then return end
    AddNode(tooltip, data)
end)

local modifier = CreateFrame("Frame")
modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
modifier:SetScript("OnEvent", function(_, _, key)
    if not ns.Get("shiftOnly") or (key ~= "LSHIFT" and key ~= "RSHIFT") then return end
    pcall(function()
        local refresh = GameTooltip["RefreshData"]
        if not (refresh and GameTooltip:IsShown()) then return end
        local get = GameTooltip["GetTooltipData"]
        local data = get and get(GameTooltip)
        local kind = data and data.type
        if data and (not Plain(kind) or kind == T.Unit) then return end
        refresh(GameTooltip)
    end)
end)
