--[[
  CVars: reads and writes the catalog's CVars and keeps the profile's values in force.
  The client saves CVars itself, but its quality presets overwrite the detail values: the profile's
  values are applied again at login, on a profile switch and after any graphics* preset CVar changed.
  Mode "normal" = the CVar itself, "raid" = its RAID<cvar> twin (an entry without twin: the CVar,
  stored under normal).
  Writes from a dragged slider are coalesced (one SetCVar per value at rest).
  CVars.Name(e, mode) / Get(e, mode) -> number|nil / Set(e, mode, v) / Reset(e, mode) / Owned(e, mode)
  CVars.Apply() / ResetAll() / Raw(name) / Write(name, value)
]]
local _, ns = ...

local CVars = {}
ns.CVars = CVars

local isSecret = issecretvalue or function() return false end
local SETTLE, PRESET_DELAY = 0.2, 0.5

local pending, flushGen = {}, 0
local applyQueued, waitCombat = false, false

function CVars.Name(e, mode)
    if mode == "raid" and e.raid then return "RAID" .. e.cvar end
    return e.cvar
end

function CVars.Raw(name)
    local ok, v = pcall(GetCVar, name)
    if not ok or v == nil or isSecret(v) then return nil end
    return v
end

function CVars.Write(name, value)
    if value == nil then return end
    pending[name] = nil
    pcall(SetCVar, name, tostring(value))
end

-- an entry without RAID twin keeps its one value under "normal" in both modes
local function Section(mode, e)
    local p = ns.module.profile
    if e and not e.raid then mode = "normal" end
    return p and p[mode == "raid" and "raid" or "normal"]
end

function CVars.Get(e, mode)
    local name = CVars.Name(e, mode)
    if pending[name] ~= nil then return pending[name] end
    return tonumber(CVars.Raw(name))
end

local function Flush(gen)
    if gen ~= flushGen then return end
    for name, v in pairs(pending) do CVars.Write(name, v) end
end

function CVars.Set(e, mode, v)
    local section = Section(mode, e)
    if not section then return end
    section[e.cvar] = v
    pending[CVars.Name(e, mode)] = v
    flushGen = flushGen + 1
    local gen = flushGen
    C_Timer.After(SETTLE, function() Flush(gen) end)
end

function CVars.Owned(e, mode)
    local section = Section(mode, e)
    return section ~= nil and section[e.cvar] ~= nil
end

local function Default(name)
    local ok, v = pcall(GetCVarDefault, name)
    if ok and v ~= nil and not isSecret(v) then return v end
end

function CVars.Reset(e, mode)
    local section = Section(mode, e)
    if section then section[e.cvar] = nil end
    local name = CVars.Name(e, mode)
    CVars.Write(name, Default(name))
end

function CVars.ResetAll()
    for cvar, e in pairs(ns.byCvar) do
        CVars.Write(cvar, Default(cvar))
        if e.raid then CVars.Write("RAID" .. cvar, Default("RAID" .. cvar)) end
    end
end

function CVars.Apply()
    if ns.disabled then return end
    if InCombatLockdown() then waitCombat = true return end
    for _, mode in ipairs({ "normal", "raid" }) do
        for cvar, v in pairs(Section(mode) or {}) do
            local e = ns.byCvar[cvar]
            if e and (mode == "normal" or e.raid) then CVars.Write(CVars.Name(e, mode), v) end
        end
    end
end

local function QueueApply()
    if applyQueued then return end
    applyQueued = true
    C_Timer.After(PRESET_DELAY, function()
        applyQueued = false
        CVars.Apply()
    end)
end

local function IsPreset(name)
    if type(name) ~= "string" or isSecret(name) then return false end
    name = name:lower()
    return name:find("^graphics") ~= nil or name:find("^raidgraphics") ~= nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, a, b)
    if event == "PLAYER_ENTERING_WORLD" then
        if a or b then CVars.Apply() end  -- login or reload
    elseif event == "PLAYER_REGEN_ENABLED" then
        if waitCombat then
            waitCombat = false
            CVars.Apply()
        end
    elseif IsPreset(a) then
        QueueApply()
    end
end)

Sendit.OnProfile(CVars.Apply)
