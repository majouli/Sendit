--[[
  Measure: counts what happens to the target (miss, dodge, parry, block, glancing, crit) per level
  difference and school kind, to settle the model's open parameters. Source: UNIT_COMBAT on "target"
  (Forever forbids addons the combat log); amounts only when not secret; no source or spell id (a
  pet's hits count too). Counts in Sendit_UpgradeDB.measure.
  /gc measure on|off|reset, /gc measure (report), /gc measure window
  Measure.Event(unit, event, flagText, amount, schoolMask);  Measure.Report() -> lines
]]
local _, ns = ...

local Measure = {}
ns.Measure = Measure

local OUTCOME = { MISS = "miss", DODGE = "dodge", PARRY = "parry", BLOCK = "block", RESIST = "resist",
                  IMMUNE = "immune", ABSORB = "absorb", EVADE = "evade" }

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

local function Store()
    local m = ns.db and ns.db.measure
    if not m then return nil end
    m.buckets = m.buckets or {}
    return m
end

local function Add(t, key, v) t[key] = (t[key] or 0) + (v or 1) end

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
    local m = Store()
    if not delta or not m then return end
    local key = (delta >= 0 and "+" or "") .. delta
    m.buckets[key] = m.buckets[key] or { physical = {}, spell = {} }
    local physical = schoolMask == 1
    local t = m.buckets[key][physical and "physical" or "spell"]
    Add(t, "n")
    local sheet = ReadCrit(physical)
    if sheet then
        Add(t, "sheetCrit", sheet)
        Add(t, "sheetN")
    end
    if ns.MeasureWindow then ns.MeasureWindow.Changed() end
    if event ~= "WOUND" then Add(t, OUTCOME[event] or "other") return end
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

local function Line(label, t)
    if (t.n or 0) == 0 then return nil end
    local line = ("%s %d: miss %.1f%%, dodge %.1f%%, parry %.1f%%, block %.1f%%, glancing %.1f%%, crit %.1f%% (sheet %.1f%%)")
        :format(label, t.n, Pct(t.miss, t.n), Pct(t.dodge, t.n), Pct(t.parry, t.n), Pct(t.block, t.n),
            Pct(t.glance, t.n), Pct(t.crit, t.n), (t.sheetN or 0) > 0 and t.sheetCrit / t.sheetN or 0)
    local hit, glance, crit = Avg(t, "hitDmg"), Avg(t, "glanceDmg"), Avg(t, "critDmg")
    if hit and glance then line = line .. (", glancing = %.1f%% of a hit"):format(glance / hit * 100) end
    if hit and crit then line = line .. (", crit = %.0f%% of a hit"):format(crit / hit * 100) end
    if (t.secretAmounts or 0) > 0 then line = line .. ", amounts secret" end
    return line
end

function Measure.Report()
    local m = Store()
    if not m or not next(m.buckets) then
        return { "measure: nothing counted yet (" .. ((m and m.on) and "running" or "off - /gc measure on") .. ")" }
    end
    local lines = { ("measure: %s, since %s"):format(m.on and "running" or "off", tostring(m.started)) }
    local keys = {}
    for k in pairs(m.buckets) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)
    for _, k in ipairs(keys) do
        lines[#lines + 1] = ("target %s levels:"):format(k)
        for _, kind in ipairs({ "physical", "spell" }) do
            local line = Line("  " .. kind, m.buckets[k][kind])
            if line then lines[#lines + 1] = line end
        end
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
        ns.db.measure = ns.db.measure or { started = date and date("%Y-%m-%d %H:%M") or "?" }
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
        local on = ns.db.measure and ns.db.measure.on
        ns.db.measure = { on = on, started = date and date("%Y-%m-%d %H:%M") or "?" }
        ns.MeasureWindow.Changed()
        ns.Print("measure: counts cleared.")
    else
        for _, line in ipairs(Measure.Report()) do ns.Print(line) end
    end
end
