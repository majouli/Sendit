--[[
  Tooltip lines. Item: "GearScore 87 (+12)   iLvl 63" - coloured like a full set of it, the change of
  your total when equipped (hidden for unusable items). Player: score, item level, spec and points;
  unknown or stale players are inspected on hover and the lines rewritten in place. Never a tooltip
  refresh from our code: that runs Blizzard's unit tooltip tainted (secret unit values).
]]
local _, ns = ...
local L = ns.L
local Score, Talents, Inspect = ns.Score, ns.Talents, ns.Inspect

local GREY, GREEN, RED = "|cff999999", "|cff40ff40", "|cffff5050"
local LABEL = L.gearScore .. " "
local OLD = 3600  -- show the age of data older than this

local shown = setmetatable({}, { __mode = "k" })

local function IsRed(c)
    local r, g, b = type(c) == "table" and ns.Safe(c.r), type(c) == "table" and ns.Safe(c.g), type(c) == "table" and ns.Safe(c.b)
    return type(r) == "number" and type(g) == "number" and type(b) == "number" and r > 0.95 and g < 0.2 and b < 0.2
end

local function Unusable(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    for i, line in ipairs(data.lines) do
        if i > 1 and type(line) == "table" and (IsRed(line.leftColor) or IsRed(line.rightColor)) then return true end
    end
    return false
end

-- the item a tooltip shows: GetItem first; comparison tooltips answer nothing on this client,
-- so the tooltip data's hyperlink or item ID next
local function ItemLink(tooltip, data)
    if type(tooltip.GetItem) == "function" then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and type(ns.Safe(link)) == "string" and link ~= "" then return link end
    end
    if type(data) ~= "table" then return nil end
    local link = ns.Safe(data.hyperlink)
    if type(link) == "string" and link ~= "" then return link end
    local id = ns.Safe(data.id)
    if type(id) == "number" then
        local ok, _, idLink = pcall(C_Item.GetItemInfo, id)
        if ok and type(ns.Safe(idLink)) == "string" then return idLink end
    end
    return nil
end

local function OnItem(tooltip, data)
    if ns.db and not ns.db.itemTip then return end
    local link = ItemLink(tooltip, data)
    if not link then return end
    local level = ns.Call(UnitLevel, "player")
    local score, ilvl, _, equipLoc = Score.Item(link, level)
    if not score or equipLoc == "INVTYPE_BODY" then return end
    local text = LABEL .. Score.Hex(Score.ItemColorValue(link, level)) .. score .. "|r"
    local delta = not Unusable(data) and Score.Delta(link)
    if delta and delta ~= 0 then
        text = text .. " " .. (delta > 0 and GREEN .. "(+" or RED .. "(") .. delta .. ")|r"
    end
    tooltip:AddDoubleLine(text, GREY .. L.itemLevel .. " " .. ilvl .. "|r", 1, 0.82, 0)
end

local function Age(t)
    local s = time() - (t or 0)
    if s < OLD then return nil end
    if s < 86400 then return L.ago:format(L.hours:format(math.floor(s / 3600))) end
    return L.ago:format(L.days:format(math.floor(s / 86400)))
end

local function ClassHex(class)
    local colors = _G["RAID_CLASS_COLORS"]
    local c = class and colors and colors[class]
    return c and c.colorStr and ("|c" .. c.colorStr) or "|cffffffff"
end

local function PlayerLines(guid)
    local entry = Inspect.Get(guid)
    if not entry then
        if Inspect.Pending(guid) then return { { LABEL .. GREY .. L.inspecting .. "|r", "" } } end
        return {}
    end
    local right = GREY .. L.itemLevel .. " " .. entry.ilvl
    local age = Age(entry.t)
    if age then right = right .. "  ·  " .. age end
    local lines = { { LABEL .. Score.Colored(entry.score), right .. "|r" } }
    local spec, points = Talents.Summary(entry.trees)
    if spec then
        lines[2] = { ClassHex(entry.class) .. spec .. "|r", GREY .. points .. "|r" }
    end
    return lines
end

local function Add(tooltip, guid)
    local lines = PlayerLines(guid)
    local first = tooltip:NumLines() + 1
    for _, l in ipairs(lines) do tooltip:AddDoubleLine(l[1], l[2], 1, 0.82, 0, 1, 1, 1) end
    shown[tooltip] = { guid = guid, first = first, count = #lines }
end

local function LineText(tooltip, side, i)
    local ok, name = pcall(tooltip.GetName, tooltip)
    name = ok and ns.Safe(name)
    return name and _G[name .. "Text" .. side .. i]
end

local function Rewrite(tooltip, state)
    local lines = PlayerLines(state.guid)
    for i, l in ipairs(lines) do
        if i <= state.count then
            local left, right = LineText(tooltip, "Left", state.first + i - 1), LineText(tooltip, "Right", state.first + i - 1)
            if left then left:SetText(l[1]) end
            if right then right:SetText(l[2]); right:Show() end
        else
            tooltip:AddDoubleLine(l[1], l[2], 1, 0.82, 0, 1, 1, 1)
        end
    end
    state.count = math.max(state.count, #lines)
    tooltip:Show()
end

local function ShowsGuid(tooltip, guid)
    if not tooltip:IsShown() then return false end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    unit = ok and ns.Safe(unit) or nil
    return unit ~= nil and ns.GUID(unit) == guid
end

Inspect.OnChange(function(guid)
    for tooltip, state in pairs(shown) do
        if state.guid == guid and ShowsGuid(tooltip, guid) then Rewrite(tooltip, state) end
    end
end)

local function OnUnit(tooltip, data)
    shown[tooltip] = nil
    if ns.db and not ns.db.playerTip then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    unit = ok and ns.Safe(unit) or nil
    if not unit or not ns.Call(UnitIsPlayer, unit) then return end
    local guid = ns.Safe(type(data) == "table" and data.guid or nil) or ns.GUID(unit)
    if not guid then return end
    Inspect.Request(unit)
    Add(tooltip, guid)
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
end
