--[[
  MinimapGlyphs: a Specials handler that removes what the engine draws on
  the minimap (player arrow, direction arrows, blips, quest area ring) while
  the minimap is fully faded.

  These ignore alpha (verified on Forever). What does not work, verified:
  texture setters (missing, or addon textures render green) and shrinking
  the Minimap (EllesmereUI measures the zone name inside it on every zone
  change; at 1 % scale the measure explodes and its bar stays huge; other
  addons resize on OnSizeChanged). What works: hiding the Minimap. Its size,
  scale and fonts stay as they are, and no installed addon reacts to it.

  - Only a Minimap that is not protected is hidden (Show/Hide of protected
    frames is off limits). A protected one only gets its icons shrunk
    (SetIconScale; Edit Mode's Icon Size comes back, else 1).
  - It is shown again only if it is still hidden. Code that shows it
    meanwhile makes it "appear" for the Fader: visible for the fade delay,
    then faded and hidden again.
  - A hidden frame has no area: HoverRect gives the rect from before, so
    hovering where the minimap was still wakes it.
  - After Show a zoom step there and back forces the map to redraw (after
    an earlier size change the terrain stayed blank until the zoom changed).
]]
local _, ns = ...

local Safe = ns.Safe

local TINY = 0.01

local MinimapGlyphs = { name = "Minimap" }
ns.MinimapGlyphs = MinimapGlyphs

local mode = nil       -- nil | "hidden" | "icons" while entered
local savedRect = nil  -- { l, b, w, h } before hiding

-- Edit Mode's Icon Size as a scale, or 1.
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

-- -> sorted names of the Minimap's methods about arrows, blips and icons
-- (/fa probe: what the client offers).
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
