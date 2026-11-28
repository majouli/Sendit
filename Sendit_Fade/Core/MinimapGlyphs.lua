--[[
  MinimapGlyphs: a Specials handler for what the engine draws on the minimap (player arrow, blips,
  quest ring), which ignores alpha. Texture setters fail and shrinking breaks addons that measure
  it; hiding the Minimap works. Only an unprotected
  Minimap is hidden (a protected one gets its icons shrunk), shown again only if still hidden, with
  the old rect for hover and a zoom step to force a redraw. Never change its size or scale.
]]
local _, ns = ...

local Safe = ns.Safe

local TINY = 0.01

local MinimapGlyphs = { name = "Minimap" }
ns.MinimapGlyphs = MinimapGlyphs

local mode = nil
local savedRect = nil

-- Edit Mode's Icon Size as a scale, or 1
local function ConfiguredIconScale()
    -- string keys: not in this client's API annotations
    local c = _G["MinimapCluster"]
    local enum = Enum and Enum["EditModeMinimapSetting"] ---@type table?
    local setting = type(enum) == "table" and rawget(enum, "IconScale")
    if type(c) == "table" and setting ~= nil and type(c.GetSettingValue) == "function" then
        local ok, v = pcall(c.GetSettingValue, c, setting)
        v = ok and Safe.Value(v)
        if type(v) == "number" and v > 0 then return v / 100 end
    end
    return 1
end

local function SetIconScale(map, scale)
    local fn = map["SetIconScale"]
    if type(fn) == "function" then fn(map, scale) end
end

local function Redraw(map)
    local zoom = Safe.Call(map, "GetZoom")
    if type(zoom) ~= "number" then return end
    local levels = Safe.Call(map, "GetZoomLevels")
    local other = zoom > 0 and zoom - 1 or zoom + 1
    if type(levels) == "number" and other >= levels then return end
    map:SetZoom(other)
    C_Timer.After(0, function() pcall(map.SetZoom, map, zoom) end)
end

local function Debug(msg)
    if ns.db and ns.db.debug then ns.Print("|cffaaaaaa[minimap]|r " .. msg) end
end

function MinimapGlyphs:Frame()
    local map = _G.Minimap
    if type(map) == "table" then return map end
end

function MinimapGlyphs:Enter(map)
    if Safe.Call(map, "IsProtected") ~= false then
        SetIconScale(map, TINY)
        mode = "icons"
        Debug("protected: icons shrunk")
        return true
    end
    local l, b, w, h = Safe.Rect(map)
    savedRect = w and { l, b, w, h } or nil
    map:Hide()
    mode = "hidden"
    Debug("hidden" .. (w and "" or " (no rect for hover)"))
    return true
end

function MinimapGlyphs:Leave(map)
    if mode == "icons" then
        SetIconScale(map, ConfiguredIconScale())
    elseif mode == "hidden" and Safe.Call(map, "IsShown") == false then
        map:Show()
        Redraw(map)
    end
    Debug("restored")
    mode, savedRect = nil, nil
    return true
end

function MinimapGlyphs:HoverRect()
    return savedRect
end

function MinimapGlyphs:Methods()
    local map = self:Frame()
    local mt = map and getmetatable(map)
    local index = mt and mt.__index
    local names = {}
    if type(index) == "table" then
        for k, v in pairs(index) do
            if type(k) == "string" and type(v) == "function"
                and (k:find("Arrow") or k:find("Blip") or k:find("POI") or k:find("Player")
                    or k:find("Icon") or k:find("Texture") or k:find("Scale")) then
                names[#names + 1] = k
            end
        end
    end
    table.sort(names)
    return names
end

ns.Specials:Register(MinimapGlyphs)
