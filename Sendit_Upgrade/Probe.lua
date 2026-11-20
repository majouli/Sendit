--[[
  Probe: /gc probe - what this client offers: every character API the model could use (exists, errors,
  secret, plain), GetItemStats and raw tooltip lines of worn and linked items; in
  Sendit_UpgradeDB.probe. Secret values are never stored.
]]
local _, ns = ...

local MAX_RETURNS = 12

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" or t == "nil" then return v end
    return "<" .. t .. ">"
end

local function Call(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return { status = "missing" } end
    local res = { pcall(fn, ...) }
    if not res[1] then return { status = "error", error = tostring(res[2]) } end
    local values, secret = {}, false
    for i = 2, math.min(#res, MAX_RETURNS + 1) do
        local v = Plain(res[i])
        if v == "<secret>" then secret = true end
        values[i - 1] = v
    end
    return { status = secret and "secret" or "ok", values = values }
end

local API_CALLS = {
    { "UnitLevel", "player" }, { "UnitClass", "player" }, { "UnitRace", "player" },
    { "UnitStat", "player", 1 }, { "UnitStat", "player", 2 }, { "UnitStat", "player", 3 },
    { "UnitStat", "player", 4 }, { "UnitStat", "player", 5 },
    { "UnitAttackPower", "player" }, { "UnitRangedAttackPower", "player" },
    { "UnitAttackSpeed", "player" }, { "UnitRangedDamage", "player" }, { "UnitDamage", "player" },
    { "UnitArmor", "player" }, { "UnitHealthMax", "player" }, { "UnitPowerMax", "player", 0 },
    { "GetCritChance" }, { "GetRangedCritChance" }, { "GetSpellCritChance", 2 }, { "GetSpellCritChance", 3 },
    { "GetHitModifier" }, { "GetSpellHitModifier" },
    { "GetSpellBonusDamage", 2 }, { "GetSpellBonusDamage", 3 }, { "GetSpellBonusHealing" },
    { "GetSpellBonusDamage", 4 }, { "GetSpellBonusDamage", 5 }, { "GetSpellBonusDamage", 6 },
    { "GetSpellBonusDamage", 7 }, { "GetSpellCritChance", 4 }, { "GetSpellCritChance", 5 },
    { "GetSpellCritChance", 6 }, { "GetSpellCritChance", 7 }, { "CanDualWield" },
    { "GetCritChanceFromStat", 2, 100 }, { "GetSpellCritChanceFromStat", 4, 100 },
    { "GetDodgeChance" }, { "GetParryChance" }, { "GetBlockChance" }, { "GetShieldBlock" },
    { "GetManaRegen" }, { "GetAttackPowerForStat", 1, 100 }, { "GetAttackPowerForStat", 2, 100 },
    { "GetCombatRating", 6 }, { "GetCombatRatingBonus", 6 },
    { "GetNumTalentTabs" }, { "GetTalentTabInfo", 1 }, { "GetTalentTabInfo", 2 }, { "GetTalentTabInfo", 3 },
    { "GetPrimaryTalentTree" }, { "GetActiveTalentGroup" },
    { "GetNumTalents", 1 }, { "GetTalentInfo", 1, 1 }, { "GetTalentTabPoints", 1 },
    { "GetUnspentTalentPoints" }, { "UnitCharacterPoints", "player" },
    { "GetInventoryItemLink", "player", 16 }, { "GetBuildInfo" }, { "GetLocale" },
}

local function ProbeApis()
    local out = {}
    for _, call in ipairs(API_CALLS) do
        local key = call[1] .. "(" .. table.concat({ select(2, unpack(call)) }, ",") .. ")"
        out[key] = Call(unpack(call))
    end
    out.C_TooltipInfo = (C_TooltipInfo and C_TooltipInfo.GetHyperlink) and "present" or "missing"
    out.TooltipDataProcessor = TooltipDataProcessor and "present" or "missing"
    -- Talent trees: the classic tab functions are missing on this client.
    for _, name in ipairs({ "C_SpecializationInfo", "C_ClassTalents", "C_Traits", "C_Talent" }) do
        out[name] = type(_G[name]) == "table" and "present" or "missing"
    end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, spec = pcall(C_SpecializationInfo.GetSpecialization)
        out["C_SpecializationInfo.GetSpecialization()"] = ok and Plain(spec) or "error"
    end
    return out
end

local function ColorHex(c)
    if type(c) ~= "table" then return nil end
    local ok, r, g, b = pcall(function() return c.r, c.g, c.b end)
    if not ok or type(r) ~= "number" then return nil end
    local function byte(x) return math.floor(x * 255 + 0.5) end
    return ("%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

local function TooltipLines(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return "missing" end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return "unavailable" end
    local lines = {}
    for i, line in ipairs(data.lines) do
        lines[i] = {
            left = Plain(line.leftText), right = Plain(line.rightText),
            leftColor = ColorHex(line.leftColor), rightColor = ColorHex(line.rightColor),
            type = Plain(line.type),
        }
    end
    return lines
end

local function ProbeItem(link)
    local entry = { link = Plain(link) }
    local ok, stats = pcall(C_Item.GetItemStats, link)
    if ok and type(stats) == "table" then
        entry.stats = {}
        for k, v in pairs(stats) do entry.stats[Plain(k)] = Plain(v) end
    else
        entry.stats = ok and "none" or ("error: " .. tostring(stats))
    end
    local info = { pcall(C_Item.GetItemInfo, link) }
    if info[1] then
        entry.info = {}
        for i = 2, 14 do entry.info[i - 1] = Plain(info[i]) end
    end
    entry.tooltip = TooltipLines(link)
    return entry
end

local function Run(args)
    local probe = { time = date and date("%Y-%m-%d %H:%M") or "?", apis = ProbeApis(), equipped = {}, linked = {} }
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and not (issecretvalue and issecretvalue(link)) then
            probe.equipped[slot] = ProbeItem(link)
        end
    end
    for _, link in ipairs(ns.Stats.Links(args)) do
        probe.linked[#probe.linked + 1] = ProbeItem(link)
    end
    ns.db.probe = probe

    local counts = { ok = 0, secret = 0, missing = 0, error = 0 }
    for _, r in pairs(probe.apis) do
        if type(r) == "table" then counts[r.status] = counts[r.status] + 1 end
    end
    local equipped = 0
    for _ in pairs(probe.equipped) do equipped = equipped + 1 end
    ns.Print(("Probe: %d APIs ok, %d secret, %d fehlen, %d Fehler; %d angelegte, %d verlinkte Items.")
        :format(counts.ok, counts.secret, counts.missing, counts.error, equipped, #probe.linked))
    ns.Print("Gespeichert. Jetzt /reload, damit es auf die Festplatte geschrieben wird.")
    return probe
end

ns.commands.probe = Run
