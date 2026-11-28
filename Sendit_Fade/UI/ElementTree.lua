--[[
  ElementTree: the data behind the Elements page. Tree:Build() -> items (families, addons, elements
  with depth), shown, faded. View state for the session (search, filter, show hidden, expanded);
  elements switched in a filtered view stay listed until the view changes.
]]
local _, ns = ...

local Tree = {}
ns.ElementTree = Tree

local Names, Safe, L = ns.Names, ns.Safe, ns.L

local FILTER_ORDER = { "all", "included", "excluded" }
function Tree.Filters()
    local list = {}
    for i, key in ipairs(FILTER_ORDER) do list[i] = { key, L["F_" .. key] } end
    return list
end
function Tree.FilterText(key) return L["F_" .. key] end
local LOCKED = { addon = true, pattern = true, builtin = true }
function Tree.LockedText(rule) return rule and LOCKED[rule] and L["LOCK_" .. rule] or nil end

local view = { search = "", filter = "all", showHidden = false }
Tree.view = view
local expanded = {}
local sticky = {}  -- switched in this view: stays listed

local function ViewChanged()
    wipe(sticky)
end

function Tree:SetSearch(text)
    text = strtrim(text):lower()
    if text == view.search then return false end
    view.search = text
    ViewChanged()
    return true
end

function Tree:SetFilter(value)
    view.filter = value
    ViewChanged()
end

function Tree:SetShowHidden(on)
    view.showHidden = on
    ViewChanged()
end

function Tree:IsOpen(key)
    return expanded[key] or view.search ~= "" or view.filter ~= "all"
end

function Tree:ToggleOpen(key)
    expanded[key] = not expanded[key] or nil
end

function Tree:PassesFilter(rule)
    if view.filter == "included" then return rule == nil end
    if view.filter == "excluded" then return rule ~= nil and rule ~= "builtin" end
    return true
end

function Tree:Matches(e)
    if view.search == "" then return true end
    local hay = (e.label .. " " .. e.name .. " " .. e.owner .. " " .. e.kind):lower()
    return hay:find(view.search, 1, true) ~= nil
end

function Tree:ToggleElement(it)
    if not it or not it.e or Tree.LockedText(it.rule) then return end
    sticky[it.e] = true
    ns.Fader:SetExcluded(it.e, it.rule == nil)
end

function Tree:FamilyOwners(fam)
    local owners = {}
    for owner in pairs(fam.members) do owners[#owners + 1] = owner end
    return owners
end

function Tree:FamilyIncluded(fam)
    for owner in pairs(fam.members) do
        if ns.profile.exclude.addons[owner] then return false end
    end
    return true
end

function Tree:Open(e)
    local cleared = false
    local _, rule = ns.Fader:Status(e)
    if not self:PassesFilter(rule) then view.filter = "all" end
    if not self:Matches(e) then
        view.search = ""
        cleared = true
    end
    if not Safe.IsVisible(e.frame) then view.showHidden = true end
    ViewChanged()
    expanded["f:" .. ns.Scanner:FamilyOf(e.owner)] = true
    expanded["a:" .. e.owner] = true
    return cleared
end

local function FirstThen(a, b, first)
    local fa, fb = a == first, b == first
    if fa ~= fb then return fa end
end

local function Listed(e, rule)
    if sticky[e] then return true end
    local shown = view.showHidden or Safe.IsVisible(e.frame) or rule == "element"
    return shown and Tree:PassesFilter(rule) and Tree:Matches(e)
end

local function Collect(elements)
    local families, famList, groups = {}, {}, {}
    local familyOf, members = {}, {}  -- owner -> family key; family key -> { owner = true }
    local shown, faded = 0, 0
    for _, e in ipairs(elements) do
        local famKey = familyOf[e.owner]
        if not famKey then
            famKey = ns.Scanner:FamilyOf(e.owner)
            familyOf[e.owner] = famKey
            members[famKey] = members[famKey] or {}
            members[famKey][e.owner] = true
        end
        local status, rule, isFaded = ns.Fader:Status(e)
        if Listed(e, rule) then
            local g = groups[e.owner]
            if not g then
                local fam = families[famKey]
                if not fam then
                    fam = { key = famKey, title = Names.Pretty(famKey), groups = {}, count = 0, faded = 0,
                            members = members[famKey] }
                    families[famKey] = fam
                    famList[#famList + 1] = fam
                end
                local rest = e.owner:sub(#famKey + 1):gsub("^[_%-%s]+", "")
                g = { owner = e.owner, title = Names.Pretty(e.owner), family = fam, items = {}, faded = 0,
                      subtitle = e.owner == famKey and ns.L.CORE or Names.Pretty(rest) }
                groups[e.owner] = g
                fam.groups[#fam.groups + 1] = g
            end
            g.items[#g.items + 1] = { e = e, status = status, rule = rule, faded = isFaded }
            g.family.count = g.family.count + 1
            shown = shown + 1
            if isFaded then
                faded = faded + 1
                g.faded = g.faded + 1
                g.family.faded = g.family.faded + 1
            end
        end
    end
    table.sort(famList, function(a, b)
        local first = FirstThen(a.key, b.key, "Blizzard")
        if first ~= nil then return first end
        return a.title:lower() < b.title:lower()
    end)
    return famList, shown, faded
end

function Tree:Build()
    local r = ns.Scanner.last
    if not r then return {}, 0, 0 end
    local famList, shown, faded = Collect(r.elements)

    local items = {}
    local function AddGroup(g, depth)
        items[#items + 1] = { group = g, depth = depth }
        if not self:IsOpen("a:" .. g.owner) then return end
        table.sort(g.items, function(a, b) return a.e.label:lower() < b.e.label:lower() end)
        for _, it in ipairs(g.items) do
            it.depth = depth + 1
            items[#items + 1] = it
        end
    end
    for _, fam in ipairs(famList) do
        if #fam.groups == 1 then
            AddGroup(fam.groups[1], 0)
        else
            items[#items + 1] = { family = fam, depth = 0 }
            if self:IsOpen("f:" .. fam.key) then
                table.sort(fam.groups, function(a, b)
                    local first = FirstThen(a.owner, b.owner, fam.key)
                    if first ~= nil then return first end
                    return a.subtitle:lower() < b.subtitle:lower()
                end)
                for _, g in ipairs(fam.groups) do AddGroup(g, 1) end
            end
        end
    end
    return items, shown, faded
end
