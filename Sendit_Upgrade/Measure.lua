--[[
  Measure: counts what happens to the target (miss, dodge, parry, block, glancing, crit) per character,
  level difference and kind, to check the model's attack table. Source: UNIT_COMBAT on "target"
  (Forever forbids addons the combat log); amounts only when not secret. UNIT_COMBAT names no source,
  so nothing is counted while a pet is out or in a group (their hits would count too). Failed attacks
  carry no real school: MISS / DODGE / PARRY / BLOCK count as physical, RESIST as spell, the rest
  (immune, evade, absorb) only under `other`.
  Sendit_UpgradeDB.measure = { on, chars = { ["Name-Realm"] = { class, started, buckets = {
      ["+2"] = { physical = {...}, spell = {...}, other = {...} } }, skipped } } }
  /gc measure on|off|reset (this character), /gc measure (report), /gc measure window
  Measure.Event(unit, event, flagText, amount, schoolMask);  Measure.Char() -> this character's table;
  Measure.Report() -> lines
]]
local _, ns = ...

local Measure = {}
ns.Measure = Measure

local PHYSICAL = { MISS = "miss", DODGE = "dodge", PARRY = "parry", BLOCK = "block" }
local SPELL = { RESIST = "resist" }

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

local function Plain(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and v ~= nil and not IsSecret(v) then return v end
    return nil
end

local function CharKey()
    local name, realm = Plain(UnitName, "player"), Plain(GetRealmName)
    return ("%s-%s"):format(name or "?", realm or "?")
end

-- this character's counts (nil while measuring was never switched on)
function Measure.Char()
    local m = ns.db and ns.db.measure
    if not m then return nil end
    m.chars = m.chars or {}
    local key = CharKey()
    local c = m.chars[key]
    if not c then
        local _, class = UnitClass("player")
        c = { class = not IsSecret(class) and class or nil, buckets = {},
              started = date and date("%Y-%m-%d %H:%M") or "?" }
        m.chars[key] = c
    end
    return c
end
local function Add(t, key, v) t[key] = (t[key] or 0) + (v or 1) end

-- a pet's or a group member's hits on the target cannot be told apart from ours
local function Shared()
    return Plain(UnitExists, "pet") == true or Plain(IsInGroup) == true
end

local function Delta()
    local level, mine = UnitLevel("target"), UnitLevel("player")
    if IsSecret(level) or IsSecret(mine) or type(level) ~= "number" or level <= 0 then return nil end
    return level - mine
end

-- the sheet's crit is secret in combat: the last plain read stands in (nil until read)
local lastCrit = {}
local function ReadCrit(physical)
    local fn = physical and GetCritChance or GetSpellCritChance
    if not fn then return nil end
    local ok, v = pcall(fn, 2)  -- spell crit: holy school; melee ignores the argument
    if ok and type(v) == "number" and not IsSecret(v) then lastCrit[physical] = v end
    return lastCrit[physical]
end
Measure.ReadCrit = ReadCrit

function Measure.Event(unit, event, flagText, amount, schoolMask)
    if unit ~= "target" or IsSecret(event) or IsSecret(flagText) or IsSecret(schoolMask) then return end
    if event == "HEAL" or event == "ENERGIZE" or event == "BLOCK_REDUCED" then return end
    if not (UnitCanAttack and UnitCanAttack("player", "target")) then return end
    local delta = Delta()
    local c = Measure.Char()
    if not delta or not c then return end
    if Shared() then Add(c, "skipped") return end
    local key = (delta >= 0 and "+" or "") .. delta
    local b = c.buckets[key] or { physical = {}, spell = {}, other = {} }
    c.buckets[key] = b
    b.other = b.other or {}
    if event ~= "WOUND" and not PHYSICAL[event] and not SPELL[event] then
        Add(b.other, event:lower())
        return
    end
    local physical
    if event == "WOUND" then physical = schoolMask == 1 else physical = PHYSICAL[event] ~= nil end
    local t = b[physical and "physical" or "spell"]
    Add(t, "n")
    local sheet = ReadCrit(physical)
    if sheet then
        Add(t, "sheetCrit", sheet)
        Add(t, "sheetN")
    end
    if ns.MeasureWindow then ns.MeasureWindow.Changed() end
    if event ~= "WOUND" then Add(t, PHYSICAL[event] or SPELL[event]) return end
    Add(t, "landed")
    local kind = flagText == "CRITICAL" and "crit" or flagText == "GLANCING" and "glance" or "hit"
    Add(t, kind)
    if type(amount) == "number" and not IsSecret(amount) and amount > 0 then
        Add(t, kind .. "Dmg", amount)
        Add(t, kind .. "DmgN")
    elseif amount ~= nil then
        Add(t, "secretAmounts")
    end
end

local function Pct(part, whole) return whole and whole > 0 and (part or 0) / whole * 100 or 0 end
local function Avg(t, kind) return (t[kind .. "N"] or 0) > 0 and t[kind] / t[kind .. "N"] or nil end

local function Line(label, t, spell)
    if (t.n or 0) == 0 then return nil end
    local line
    if spell then
        line = ("%s %d: resist %.1f%%, crit %.1f%% (sheet %.1f%%)"):format(label, t.n, Pct(t.resist, t.n),
            Pct(t.crit, t.n), (t.sheetN or 0) > 0 and t.sheetCrit / t.sheetN or 0)
    else
        line = ("%s %d: miss %.1f%%, dodge %.1f%%, parry %.1f%%, block %.1f%%, glancing %.1f%%, crit %.1f%% (sheet %.1f%%)")
            :format(label, t.n, Pct(t.miss, t.n), Pct(t.dodge, t.n), Pct(t.parry, t.n), Pct(t.block, t.n),
                Pct(t.glance, t.n), Pct(t.crit, t.n), (t.sheetN or 0) > 0 and t.sheetCrit / t.sheetN or 0)
    end
    local hit, glance, crit = Avg(t, "hitDmg"), Avg(t, "glanceDmg"), Avg(t, "critDmg")
    if hit and glance then line = line .. (", glancing = %.1f%% of a hit"):format(glance / hit * 100) end
    if hit and crit then line = line .. (", crit = %.0f%% of a hit"):format(crit / hit * 100) end
    if (t.secretAmounts or 0) > 0 then line = line .. ", amounts secret" end
    return line
end

local function OtherLine(t)
    local parts = {}
    for k, v in pairs(t or {}) do parts[#parts + 1] = ("%s %d"):format(k, v) end
    if #parts == 0 then return nil end
    table.sort(parts)
    return "  other: " .. table.concat(parts, ", ")
end

function Measure.Report()
    local m, c = ns.db and ns.db.measure, Measure.Char()
    if not c or not next(c.buckets) then
        return { "measure: nothing counted yet for " .. CharKey() .. " ("
            .. ((m and m.on) and "running" or "off - /gc measure on") .. ")" }
    end
    local lines = { ("measure %s (%s): %s, since %s"):format(CharKey(), tostring(c.class),
        m.on and "running" or "off", tostring(c.started)) }
    if (c.skipped or 0) > 0 then
        lines[#lines + 1] = ("  %d events skipped (pet out or in a group)"):format(c.skipped)
    end
    local keys = {}
    for k in pairs(c.buckets) do keys[#keys + 1] = k end
    table.sort(keys, function(x, y) return tonumber(x) < tonumber(y) end)
    for _, k in ipairs(keys) do
        local b = c.buckets[k]
        lines[#lines + 1] = ("target %s levels:"):format(k)
        lines[#lines + 1] = Line("  physical", b.physical)
        lines[#lines + 1] = Line("  spell", b.spell, true)
        lines[#lines + 1] = OtherLine(b.other)
    end
    return lines
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_COMBAT" then Measure.Event(...) return end
    ReadCrit(true)
    ReadCrit(false)
    if event == "PLAYER_LOGIN" and ns.db and ns.db.measure and ns.db.measure.on then
        frame:RegisterUnitEvent("UNIT_COMBAT", "target")
    end
end)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

function ns.commands.measure(arg)
    arg = strtrim(arg or ""):lower()
    if arg == "on" then
        ns.db.measure = ns.db.measure or {}
        ns.db.measure.on = true
        ReadCrit(true)
        ReadCrit(false)
        frame:RegisterUnitEvent("UNIT_COMBAT", "target")
        ns.Print("measure on: fight as usual with the mob targeted; /gc measure shows the counts.")
    elseif arg == "off" then
        if ns.db.measure then ns.db.measure.on = nil end
        frame:UnregisterEvent("UNIT_COMBAT")
        ns.Print("measure off (counts kept; /gc measure reset clears them).")
    elseif arg == "window" then
        ns.MeasureWindow.Toggle()
    elseif arg == "reset" then
        local m = ns.db.measure
        if m and m.chars then m.chars[CharKey()] = nil end
        ns.MeasureWindow.Changed()
        ns.Print("measure: counts of " .. CharKey() .. " cleared.")
    else
        for _, line in ipairs(Measure.Report()) do ns.Print(line) end
    end
end
