local _, ns = ...

local P = {}
ns.Professions = P

P.KEYS = { "disenchant", "skinning", "mining", "herbalism" }

local SPELLS = {
    disenchant = { 13262 },
    skinning   = { 8613, 8617, 8618, 10768 },
    mining     = { 2580 },
    herbalism  = { 2383 },
}

local Plain = ns.Plain

local legacySpell = "IsPlayerSpell"
local IsSpellKnown = (C_SpellBook and C_SpellBook.IsSpellKnown) or _G[legacySpell]
local GetNumSkillLines, GetSkillLineInfo = _G["GetNumSkillLines"], _G["GetSkillLineInfo"]

local cache

local function SkillNames()
    local names = {}
    if not (GetNumSkillLines and GetSkillLineInfo) then return names, false end
    for i = 1, GetNumSkillLines() or 0 do
        local name = GetSkillLineInfo(i)
        if Plain(name) then names[name] = true end
    end
    return names, true
end

local function Build()
    local names, haveSkills = SkillNames()
    cache = {}
    for _, prof in ipairs(P.KEYS) do
        local known = false
        if IsSpellKnown then
            for _, spell in ipairs(SPELLS[prof]) do
                if IsSpellKnown(spell) then known = true end
            end
        end
        for _, name in ipairs(ns.ClientNames.professions[prof]) do
            if names[name] then known = true end
        end
        if not IsSpellKnown and not haveSkills then known = true end
        cache[prof] = known
    end
end

function P.Knows(prof)
    if not cache then Build() end
    return cache[prof]
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function()
    cache = nil
    ns.SettingsChanged()
end)
