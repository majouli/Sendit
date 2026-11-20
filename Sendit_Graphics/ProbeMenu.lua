--[[
  ProbeMenu: /sendit graphics menu - which catalog CVars each quality setting of the client's graphics
  menu drives and what its top level sets them to. Per menu CVar: level 0, read the catalog, the
  menu's top level (lower when the engine rejects it), read again; catalog CVars that changed are its
  own. Everything is restored afterwards (menu CVars first, then the catalog values).
  SenditGraphicsDB.menu = { build, [menuCvar] = { top, sets = { [cvar] = { low, high } } } }
  Top levels: the client's graphics settings definitions (Blizzard_SettingsDefinitions_Shared/Graphics.lua).
]]
local _, ns = ...

local MENU = {
    graphicsShadowQuality = 5, graphicsLightMode = 3, graphicsLiquidDetail = 3, graphicsPBRLiquidDetail = 2,
    graphicsParticleDensity = 5, graphicsSSAO = 4, graphicsDepthEffects = 3, graphicsComputeEffects = 4,
    graphicsOutlineMode = 2, graphicsSpellDensity = 2, graphicsProjectedTextures = 1, graphicsViewDistance = 9,
    graphicsEnvironmentDetail = 9, graphicsGroundClutter = 9, graphicsTextureResolution = 2,
}

local function Raw(name) return ns.CVars.Raw(name) end

local function Snapshot()
    local s = {}
    for cvar in pairs(ns.byCvar) do s[cvar] = Raw(cvar) end
    return s
end

local function SetLevel(menu, level)
    for v = level, 0, -1 do
        pcall(SetCVar, menu, tostring(v))
        if tonumber(Raw(menu)) == v then return v end
    end
end

local function Probe()
    if InCombatLockdown() then return Sendit.Print("graphics menu probe: not in combat") end
    local saved, savedMenu = Snapshot(), {}
    for menu in pairs(MENU) do savedMenu[menu] = Raw(menu) end
    local out = { build = select(2, GetBuildInfo()) }
    for menu, top in pairs(MENU) do
        if savedMenu[menu] then
            SetLevel(menu, 0)
            local low = Snapshot()
            local reached = SetLevel(menu, top)
            local high = Snapshot()
            local sets = {}
            for cvar, v in pairs(high) do
                if v ~= low[cvar] then sets[cvar] = { low[cvar], v } end
            end
            out[menu] = { top = reached, sets = sets }
            pcall(SetCVar, menu, savedMenu[menu])
        end
    end
    for cvar, v in pairs(saved) do ns.CVars.Write(cvar, v) end
    SenditGraphicsDB = type(SenditGraphicsDB) == "table" and SenditGraphicsDB or {}
    SenditGraphicsDB.menu = out
    Sendit.Print("graphics menu probe: done, saved on /reload")
end

ns.MenuProbe = Probe
