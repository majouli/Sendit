--[[
  Effects: green tooltip lines GetItemStats does not cover - weapon enchants, damage procs, school
  spell damage (matched against the client's own texts, Data/SchoolDamage.lua).
  Effects.Parse(text) -> { kind = "stat" | "weaponDamage" | "proc", ... } | nil ("not rated")
  Narrow on purpose (a wrong guess is worse than "not rated"): enchant lines with one number and a
  known stat name; equip sentences stay with GetItemStats; use effects and set bonuses stay unrated.
  Line prefixes from the client's global strings, fallbacks in Locale.lua (client language).
]]
local _, ns = ...
local L = ns.L

local Effects = {}
ns.Effects = Effects

-- Global string -> prefix text ("Verzaubert: %s" -> "Verzaubert: ").
local function Prefix(globalName, fallback)
    local g = _G[globalName]
    if type(g) == "string" and g ~= "" then return (g:gsub("%%s", "")) end
    return fallback
end

local function StartsWith(text, prefix)
    return prefix ~= nil and prefix ~= "" and text:sub(1, #prefix) == prefix
end

-- { { name = "ausdauer", key = "sta" }, ... } longest name first, so
-- "Distanzangriffskraft" wins over "Angriffskraft".
local names
local function StatNames()
    if names then return names end
    names = {}
    local seen = {}
    local function add(name, key)
        if type(name) == "string" and name ~= "" and ns.Stats.KEYS[key] and not seen[name:lower()] then
            seen[name:lower()] = true
            names[#names + 1] = { name = name:lower(), key = key }
        end
    end
    for apiKey, key in pairs(ns.Stats.API_KEYS) do add(_G[apiKey], key) end
    for key, name in pairs(ns.ParseStatNames) do add(name, key) end
    table.sort(names, function(a, b) return #a.name > #b.name end)
    return names
end

local function Proc(body)
    local lower = body:lower()
    if not lower:find(ns.Parse.damage, 1, true) then return nil end
    local n = ns.Stats.Numbers(body)
    if #n == 0 or #n > 2 then return nil end
    return { kind = "proc", min = n[1], max = n[2] or n[1] }
end

local function Enchant(body)
    local n = ns.Stats.Numbers(body)
    if #n ~= 1 then return nil end
    local lower = body:lower()
    if lower:find(ns.Parse.weaponDamage, 1, true) then
        return { kind = "weaponDamage", value = n[1] }
    end
    for _, s in ipairs(StatNames()) do
        if lower:find(s.name, 1, true) then
            local sign = body:find("%-%d") and -1 or 1
            return { kind = "stat", key = s.key, value = sign * n[1] }
        end
    end
    return nil
end

-- Client texts with $s1 -> Lua patterns, for this client's language.
local schoolPatterns
local function SchoolPatterns()
    if schoolPatterns then return schoolPatterns end
    schoolPatterns = {}
    local locale = GetLocale and GetLocale() or "enUS"
    locale = ({ enGB = "enUS", esMX = "esES" })[locale] or locale
    local texts = ns.SchoolDamageTexts and ns.SchoolDamageTexts[locale] or {}
    for _, t in ipairs(texts) do
        local head, tail = t[2]:match("^(.-)%$s1(.*)$")
        if head then
            local function esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
            schoolPatterns[#schoolPatterns + 1] = { school = t[1], pattern = esc(head) .. "(%d+)" .. esc(tail) .. "$" }
        end
    end
    return schoolPatterns
end

function Effects.School(text)
    if type(text) ~= "string" then return nil end
    for _, p in ipairs(SchoolPatterns()) do
        local n = text:match(p.pattern)
        if n then return { kind = "stat", key = p.school .. "Dmg", value = tonumber(n) } end
    end
    return nil
end

function Effects.Parse(text)
    if type(text) ~= "string" then return nil end
    local school = Effects.School(text)
    if school then return school end
    local enchant = Prefix("ENCHANTED_TOOLTIP_LINE", ns.Parse.enchant)
    local proc = Prefix("ITEM_SPELL_TRIGGER_ONPROC", ns.Parse.proc)
    if StartsWith(text, enchant) then return Enchant(text:sub(#enchant + 1)) end
    if StartsWith(text, proc) then return Proc(text:sub(#proc + 1)) end
    return nil
end
