--[[
  Build: a catalog macro as the client needs it - spell names from the client (its language, Forever's
  renames), so /cast finds them.
  Build.Macro(entry) -> { entry, name (<= 16 bytes), icon, body, text (description), known, lacks = { names } }
    known: the character knows the macro's first spell (by id or, for talent variants, by name);
    lacks: its other spells it does not know yet.
  Build.List(class) -> the class's macros, Build.Spell(id) -> name, icon
]]
local _, ns = ...
local Build = {}
ns.Build = Build

local NAME_MAX = 16
local QUESTION = 134400
local isSecret = issecretvalue or function() return false end
local legacyKnown, legacyPet = "IsPlayerSpell", "IsSpellKnown"

local function Call(fn, ...)
    if not fn then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok or isSecret(a) then return nil end
    return a, b
end

function Build.Spell(id)
    local name = Call(C_Spell and C_Spell.GetSpellName, id)
    return name, Call(C_Spell and C_Spell.GetSpellTexture, id)
end

local function KnownID(id)
    local fn = (C_SpellBook and C_SpellBook.IsSpellKnown) or _G[legacyKnown]
    if Call(fn, id) == true then return true end
    return Call(_G[legacyPet], id, true) == true  -- a pet's spell
end

local function Known(id, name)
    if KnownID(id) then return true end
    local info = name and Call(C_Spell and C_Spell.GetSpellInfo, name)
    local other = type(info) == "table" and info.spellID
    return type(other) == "number" and other ~= id and KnownID(other)
end

-- "{9634|5487}" -> the first known alternative, else the first that has a name
local function Resolve(token)
    local first
    for digits in token:gmatch("%d+") do
        local id = tonumber(digits)
        local name, icon = Build.Spell(id)
        if name then
            if Known(id, name) then return { id = id, name = name, icon = icon, known = true } end
            first = first or { id = id, name = name, icon = icon, known = false }
        end
    end
    return first
end

-- cut at a character boundary (UTF-8 continuation bytes are 0x80-0xBF)
local function Cut(text, max)
    if #text <= max then return text end
    local n = max
    while n > 0 and text:byte(n + 1) and text:byte(n + 1) >= 0x80 and text:byte(n + 1) < 0xC0 do n = n - 1 end
    return text:sub(1, n)
end

local function Describe(kind, spells)
    local text = ns.L["kind_" .. kind] or ""
    return (text:gsub("{(%d)}", function(i)
        local s = spells[tonumber(i)]
        return s and s.name or "?"
    end))
end

function Build.Macro(entry)
    local spells, seen, failed = {}, {}, false
    local body = entry.body:gsub("{([%d|]+)}", function(token)
        local s = Resolve(token)
        if not s then
            failed = true
            return ""
        end
        if not seen[token] then
            seen[token] = true
            spells[#spells + 1] = s
        end
        return s.name
    end)
    if failed then return nil end
    local main = spells[1]
    local lacks = {}
    for i = 2, #spells do
        if not spells[i].known then lacks[#lacks + 1] = spells[i].name end
    end
    return {
        entry = entry,
        name = Cut(main and main.name or ns.L["name_" .. entry.kind] or entry.kind, NAME_MAX),
        icon = main and main.icon or (ns.ICONS[entry.kind] and "Interface\\Icons\\" .. ns.ICONS[entry.kind]) or QUESTION,
        macroIcon = main and QUESTION or ns.ICONS[entry.kind] or QUESTION,
        body = body,
        text = Describe(entry.kind, spells),
        known = main == nil or main.known,
        lacks = lacks,
    }
end

function Build.List(class)
    local out = {}
    for _, entry in ipairs(ns.Catalog[class] or {}) do
        local m = Build.Macro(entry)
        if m then out[#out + 1] = m end
    end
    return out
end
