--[[
  Tooltip: a verdict against the worn item ("Sendit: Upgrade (+6,0% Damage)", a disagreeing second
  metric, "Shift: Details"); with Shift the replaced item, both metrics, the spec, the per-stat breakdown
  and unrated lines. Uses TooltipDataProcessor.
]]
local _, ns = ...
local L = ns.L

local LABEL = "|cff66c2ffSendit:|r "
local GREEN, RED, GREY, DIM = "|cff40ff40", "|cffff5050", "|cff999999", "|cffb0b0b0"
local MAX_BREAKDOWN = 6
-- below this the model cannot tell items apart: a sidegrade
local SIDEGRADE_PCT = 0.5

local function Num(v, decimals)
    local s = ("%." .. (decimals or 1) .. "f"):format(v)
    return (s:gsub("%.", L.decimal))
end

local function Signed(v, decimals)
    return (v >= 0 and "+" or "") .. Num(v, decimals)
end

local function Color(v)
    if v > 0.05 then return GREEN end
    if v < -0.05 then return RED end
    return GREY
end

local function Pct(c)
    return c.pct or (c.abs > 0 and math.huge or c.abs < 0 and -math.huge or 0)
end

local function Verdict(c)
    local pct = Pct(c)
    local share = c.pct and (" (" .. Signed(c.pct) .. "% " .. c.label .. ")") or ""
    if pct >= SIDEGRADE_PCT then return GREEN .. L.upgrade .. share .. "|r" end
    if pct <= -SIDEGRADE_PCT then return RED .. L.downgrade .. share .. "|r" end
    return GREY .. L.sidegrade .. share .. "|r"
end

function ns.FormatChange(c)
    local text = c.label .. ": " .. Signed(c.abs, c.unit == "EHP" and 0 or 1) .. " " .. c.unit
    if c.pct then text = text .. " (" .. Signed(c.pct) .. "%)" end
    return Color(c.pct or c.abs) .. text .. "|r"
end

-- The secondary metric only speaks up when it disagrees noticeably.
local function TradeOff(r)
    local p, q = Pct(r.primary), Pct(r.secondary)
    if math.abs(q) < SIDEGRADE_PCT or math.abs(p) < SIDEGRADE_PCT or (p > 0) == (q > 0) then return nil end
    local amount = r.secondary.pct and (Signed(r.secondary.pct) .. "%")
        or (Signed(r.secondary.abs, 0) .. " " .. r.secondary.unit)
    return Color(q) .. L.but:format(r.secondary.label, amount) .. "|r"
end

local function Replaced(r)
    local gear = r.ctx.gear
    local old = gear[r.slot]
    local names = { old and old.link or L.emptySlot }
    if r.slot == 16 and r.item.equipLoc == "INVTYPE_2HWEAPON" and gear[17] then
        names[2] = gear[17].link
    end
    return table.concat(names, " + ")
end

local function AddDetails(tooltip, r)
    tooltip:AddLine("  " .. DIM .. L.instead .. "|r " .. Replaced(r))
    tooltip:AddLine("  " .. ns.FormatChange(r.primary))
    tooltip:AddLine("  " .. ns.FormatChange(r.secondary))
    tooltip:AddLine("  " .. DIM .. L.spec .. ": " .. L.specs[r.ctx.specKey]
        .. (ns.charDB and ns.charDB.spec and "" or (" (" .. L.specAuto .. ")")) .. "|r")
    for i, b in ipairs(r.breakdown) do
        if i > MAX_BREAKDOWN then break end
        local amount = b.amount and (Signed(b.amount, 0) .. " ") or ""
        tooltip:AddDoubleLine("    " .. amount .. b.name, Signed(b.value, 2) .. " " .. r.primary.unit,
            0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    end
    for _, text in ipairs(r.item.unrated) do
        tooltip:AddLine("  " .. GREY .. L.unrated .. ": " .. text .. "|r", 1, 1, 1, true)
    end
end

function ns.AddCompareLines(tooltip, r)
    if r.status == "unusable" then
        tooltip:AddLine(LABEL .. GREY .. L.unusable .. "|r")
        return
    elseif r.status == "noCompare" then
        tooltip:AddLine(LABEL .. GREY .. L.noCompare .. "|r")
        return
    elseif r.status ~= "ok" then
        return
    end
    local gate = r.levelGate and (" " .. GREY .. "(" .. L.fromLevel:format(r.levelGate) .. ")|r") or ""
    tooltip:AddLine(LABEL .. Verdict(r.primary) .. gate)
    local tradeOff = TradeOff(r)
    if tradeOff then tooltip:AddLine("  " .. tradeOff) end
    if IsShiftKeyDown() then
        AddDetails(tooltip, r)
    else
        tooltip:AddLine("  " .. GREY .. L.shiftHint .. "|r")
    end
end

local function ItemLink(tooltip)
    if type(tooltip.GetItem) ~= "function" then return nil end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then return nil end
    return link
end
ns.TooltipItemLink = ItemLink

local function OnItem(tooltip)
    local link = ItemLink(tooltip)
    if not link then return end
    local r = ns.Compare.Evaluate(link)
    if r then ns.AddCompareLines(tooltip, r) end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
end

-- Shift rebuilds the open tooltip - item tooltips only: a refresh from addon code runs
-- Blizzard's rebuild tainted, and on a unit tooltip that hits secret unit values
local function OnModifier(_, _, key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    if not GameTooltip:IsShown() or not ItemLink(GameTooltip) then return end
    local method = "RefreshData"  -- tooltip data API; looked up by string, annotations differ
    local refresh = GameTooltip[method]
    if refresh then pcall(refresh, GameTooltip) end
end
ns.OnTooltipModifier = OnModifier

local modifier = CreateFrame("Frame")
modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
modifier:SetScript("OnEvent", OnModifier)
