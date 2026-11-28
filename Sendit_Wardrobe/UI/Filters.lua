--[[
  Filters: the chip row over the list - slot (looks and highlights), armour, source, collected. A chip
  shows its name, or its choice in gold while that narrows the list; it opens a menu of choices.
  Filters.Create(parent, onChange) -> bar;  bar:Refresh(tab)   (values in Browse.Get / Set)
]]
local _, ns = ...
local L, Browse, Slots = ns.L, ns.Browse, ns.Slots
local W = Sendit.Widgets
local Filters = {}
ns.Filters = Filters
local GROUPS = { "auction", "vendor", "quest", "crafted", "dungeon", "drop", "rep", "pvp", "special", "unknown" }
local DEFAULT = { slot = "all", armor = "mine", source = "all", have = "all" }

local function Armor(sub)
    return Sendit.Locale.SubClass(4, sub) or ns.Read(C_Item.GetItemSubClassInfo, 4, sub) or tostring(sub)
end

local OPTIONS = {
    slot = function()
        local out = { { "all", L.allSlots } }
        for _, key in ipairs(Slots.ORDER) do out[#out + 1] = { key, Slots.Name(key) } end
        return out
    end,
    armor = function()
        local out = { { "mine", L.armorMine }, { "all", L.armorAll } }
        for sub = 1, 4 do out[#out + 1] = { 400 + sub, Armor(sub) } end
        return out
    end,
    source = function()
        local out = { { "all", L.sourceAll } }
        for _, g in ipairs(GROUPS) do out[#out + 1] = { g, L["group_" .. g] } end
        return out
    end,
    have = function()
        return { { "all", L.haveAll }, { "missing", L.haveMissing }, { "have", L.haveHave } }
    end,
}
local ORDER = { "slot", "armor", "source", "have" }
local CHIP, GAP = 220, 6  -- a chip's widest; the shown chips share the row

local function Label(key)
    local value = Browse.Get(key) or DEFAULT[key]
    for _, opt in ipairs(OPTIONS[key]()) do
        if opt[1] == value and value ~= DEFAULT[key] then return opt[2], true end
    end
    return L["chip_" .. key], false
end

function Filters.Create(parent, onChange)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(26)
    bar.chips = {}
    for _, key in ipairs(ORDER) do
        bar.chips[key] = W.Chip(bar, function(chip)
            W.ShowMenu(chip, OPTIONS[key](), Browse.Get(key) or DEFAULT[key], function(value)
                Browse.Set(key, value)
                onChange()
            end)
        end, CHIP)
    end

    local function Shown(key, tab)
        return tab ~= "outfits" and (key ~= "slot" or tab == "looks" or tab == "highlights")
    end

    function bar:Refresh(tab)
        local count = 0
        for _, key in ipairs(ORDER) do if Shown(key, tab) then count = count + 1 end end
        local share = count > 0 and math.floor((self:GetParent():GetWidth() - GAP * (count - 1)) / count) or 0
        local x = 0
        for _, key in ipairs(ORDER) do
            local chip = self.chips[key]
            chip:SetShown(Shown(key, tab))
            if chip:IsShown() then
                local text, active = Label(key)
                chip:SetLabel(text, active)
                if share > 40 and chip:GetWidth() > share then
                    chip:SetWidth(share)
                    chip.text:SetWidth(share - 36)
                end
                chip:ClearAllPoints()
                chip:SetPoint("LEFT", x, 0)
                x = x + chip:GetWidth() + GAP
            end
        end
    end
    return bar
end
