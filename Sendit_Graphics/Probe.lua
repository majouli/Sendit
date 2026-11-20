--[[
  Probe: /sendit graphics probe - the range the engine accepts for each catalog CVar. The engine
  rejects (does not clamp) a value outside its range, so a write is "accepted" when the CVar reads
  back the written value. Ranges: binary search between the current value and +-100000 on the
  entry's step; switches/choices: which listed values are accepted. Old values restored (same frame).
  SenditGraphicsDB.probe = { build, [cvar] = { was, max, min } | { was, accepts = { v = true } } }
  max / min = "open" when +-100000 was accepted. /sendit graphics opens the page; /sendit graphics menu: ProbeMenu.
]]
local _, ns = ...

local FAR = 100000

local function Accepts(name, v)
    pcall(SetCVar, name, tostring(v))
    local got = tonumber(ns.CVars.Raw(name))
    return got ~= nil and math.abs(got - v) < 1e-6
end

-- the last accepted value walking from `from` (accepted) towards `to`, on steps of `step`
local function Edge(name, from, to, step)
    if Accepts(name, to) then return "open" end
    local good, bad = 0, math.floor(math.abs(to - from) / step)
    local dir = to > from and 1 or -1
    while bad - good > 1 do
        local mid = math.floor((good + bad) / 2)
        if Accepts(name, from + dir * mid * step) then good = mid else bad = mid end
    end
    return tostring(from + dir * good * step)
end

local function Measure(e)
    local was = ns.CVars.Raw(e.cvar)
    local n = tonumber(was)
    if n == nil then return nil end
    local out = { was = was }
    if e.kind == "range" then
        out.max = Edge(e.cvar, n, FAR, e.step)
        out.min = Edge(e.cvar, n, -FAR, e.step)
    else
        out.accepts = {}
        for _, v in ipairs(e.kind == "switch" and { 0, 1 } or e.choices) do
            out.accepts[tostring(v)] = Accepts(e.cvar, v)
        end
    end
    ns.CVars.Write(e.cvar, was)
    return out
end

local function Probe()
    if InCombatLockdown() then return Sendit.Print("graphics probe: not in combat") end
    local out = { build = select(2, GetBuildInfo()) }
    local n = 0
    for cvar, e in pairs(ns.byCvar) do
        out[cvar] = Measure(e)
        if out[cvar] then n = n + 1 end
    end
    SenditGraphicsDB = type(SenditGraphicsDB) == "table" and SenditGraphicsDB or {}
    SenditGraphicsDB.probe = out
    Sendit.Print("graphics probe: " .. n .. " CVars measured, saved on /reload")
end

Sendit.commands.graphics = function(rest)
    rest = (rest or ""):lower()
    if rest:find("^%s*probe") then return Probe() end
    if rest:find("^%s*menu") then return ns.MenuProbe() end
    Sendit.Options:Show("graphics")
end
