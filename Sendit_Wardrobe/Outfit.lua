--[[
  Outfit: what the model wears (one item per slot) and the saved outfits (Sendit_WardrobeDB.outfits).
  Outfit.Get(slot) / Items() -> { [slot] = itemID } / Put(itemID) / Clear(slot) / Empty()
  Outfit.FromSet(set) (only its pieces) / FromEquipped() (the character's own gear)
  Outfit.Name() -> the loaded outfit's name | nil;  Outfit.Saved() -> { { name, items } }
  Outfit.Save(name) -> index (an outfit of that name is overwritten) / Load(index) / Delete(index)
  Outfit.OnChange(fn)   after every change. A two-hander in the main hand clears the off hand.
]]
local _, ns = ...
local Catalog, Slots = ns.Catalog, ns.Slots
local Outfit = {}
ns.Outfit = Outfit
local items, name, listeners = {}, nil, {}

local function Changed()
    for _, fn in ipairs(listeners) do fn() end
end

function Outfit.OnChange(fn) listeners[#listeners + 1] = fn end
function Outfit.Get(slot) return items[slot] end
function Outfit.Items() return items end
function Outfit.Name() return name end

local function Place(id)
    local it = Catalog.Item(id)
    if not it or not it.slot then return false end
    items[it.slot] = id
    if it.inv == Slots.TWO_HAND then items.off = nil end
    if it.slot == "off" and items.main then
        local main = Catalog.Item(items.main)
        if main and main.inv == Slots.TWO_HAND then items.main = nil end
    end
    return true
end

function Outfit.Put(id)
    if Place(id) then Changed() end
end

function Outfit.Clear(slot)
    items[slot] = nil
    Changed()
end

function Outfit.Empty()
    wipe(items)
    name = nil
    Changed()
end

function Outfit.FromSet(set)
    wipe(items)
    for _, id in ipairs(set.items) do Place(id) end
    name = nil
    Changed()
end

function Outfit.FromEquipped()
    wipe(items)
    for _, slot in ipairs(Slots.ORDER) do
        local id = ns.Read(GetInventoryItemID, "player", Slots.Equipped(slot))
        if type(id) == "number" and Catalog.Item(id) then items[slot] = id end
    end
    name = nil
    Changed()
end

function Outfit.Saved() return ns.store and ns.store.outfits or {} end

function Outfit.Save(text)
    local list = ns.store and ns.store.outfits
    text = text and strtrim(text) or ""
    if not list or text == "" or not next(items) then return nil end
    local copy = {}
    for slot, id in pairs(items) do copy[slot] = id end
    local index = #list + 1
    for i, o in ipairs(list) do if o.name == text then index = i end end
    list[index] = { name = text, items = copy }
    name = text
    Changed()
    return index
end

function Outfit.Load(index)
    local o = Outfit.Saved()[index]
    if not o then return end
    wipe(items)
    for _, slot in ipairs(Slots.ORDER) do
        local id = type(o.items) == "table" and o.items[slot]
        if type(id) == "number" then items[slot] = id end
    end
    name = o.name
    Changed()
end

function Outfit.Delete(index)
    local list = ns.store and ns.store.outfits
    if not list or not list[index] then return end
    if list[index].name == name then name = nil end
    table.remove(list, index)
    Changed()
end
