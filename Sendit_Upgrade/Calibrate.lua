--[[
  Calibrate: the character's real agility per 1 % crit (intellect per 1 % spell crit) at its level -
  out-of-combat reads stored as samples (Sendit_UpgradeCharDB.calib, reset on level-up), the ratio is
  the Theil-Sen slope between them (one buffed sample does not move it).
  Calibrate.Sample(snapshot);  Calibrate.Ratios(level) -> { agi?, int? }
]]
local _, ns = ...

local Calibrate = {}
ns.Calibrate = Calibrate

local MIN_SPREAD = 4        -- stat points two samples must differ by
local MAX_SAMPLES = 20
local PLAUSIBLE = { 2, 150 } -- stat points per 1%: anything outside is a bad sample set

local function Median(list)
    table.sort(list)
    local n = #list
    if n % 2 == 1 then return list[(n + 1) / 2] end
    return (list[n / 2] + list[n / 2 + 1]) / 2
end

function Calibrate.Ratio(samples)
    local slopes = {}
    for i = 1, #samples do
        for j = i + 1, #samples do
            local dx = samples[j][1] - samples[i][1]
            if math.abs(dx) >= MIN_SPREAD then
                slopes[#slopes + 1] = (samples[j][2] - samples[i][2]) / dx
            end
        end
    end
    if #slopes == 0 then return nil end
    local slope = Median(slopes)
    if slope <= 0 then return nil end
    local ratio = 1 / slope
    if ratio < PLAUSIBLE[1] or ratio > PLAUSIBLE[2] then return nil end
    return ratio
end

local function Add(samples, x, y)
    for _, s in ipairs(samples) do
        if s[1] == x then
            s[2] = y
            return
        end
    end
    samples[#samples + 1] = { x, y }
    if #samples > MAX_SAMPLES then table.remove(samples, 1) end
end

function Calibrate.Sample(s)
    local db = ns.charDB
    if not db or not s then return end
    if not db.calib or db.calib.level ~= s.level then
        db.calib = { level = s.level, agi = {}, int = {} }
    end
    Add(db.calib.agi, s.agi, s.crit - (s.gearCrit or 0))
    Add(db.calib.int, s.int, s.spellCrit - (s.gearSpellCrit or 0))
end

function Calibrate.Ratios(level)
    local c = ns.charDB and ns.charDB.calib
    if not c or c.level ~= level then return {} end
    return { agi = Calibrate.Ratio(c.agi), int = Calibrate.Ratio(c.int) }
end
