--[[
  Slider: the detail slider - accent fill, round thumb, a muted tick at the client default, a bright
  tick at what the graphics menu reaches (e.menu) and a warning band where it costs frame rate (e.cost).
  ns.Slider(parent, e, get, set, default) -> slider (width from its anchors);  slider:Refresh()
  get() -> number|nil, set(v) gets values rounded to e.step; default() -> number|nil.
  No mouse wheel: the wheel scrolls the page (a wheel over a slider must never change a value).
]]
local _, ns = ...
local T = Sendit.Theme

function ns.Slider(parent, e, get, set, default)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(18)
    s:SetMinMaxValues(e.lo, e.hi)
    s:SetValueStep(e.step)
    s:SetObeyStepOnDrag(true)

    local track = T.Fill(s, "track", "ARTWORK", 0)
    track:SetHeight(6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    local thumb = T.Circle(s, "text", 16, "OVERLAY", 1)
    s:SetThumbTexture(thumb)

    local fill = T.Fill(s, "accent", "ARTWORK", 1)
    fill:SetHeight(6)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")

    local band = T.Fill(s, "warning", "ARTWORK", 0, 0.45)
    band:SetHeight(6)
    local tick = T.Fill(s, "textMuted", "ARTWORK", 2)
    tick:SetSize(2, 12)
    local menuTick = T.Fill(s, "text", "ARTWORK", 2)
    menuTick:SetSize(2, 16)

    local function X(v)
        return math.max(0, math.min(1, (v - e.lo) / (e.hi - e.lo))) * (s:GetWidth() or 0)
    end

    local function Place(t, v)
        t:SetShown(v ~= nil)
        if v == nil then return end
        t:ClearAllPoints()
        t:SetPoint("CENTER", s, "LEFT", X(v), 0)
    end

    local function PlaceTick()
        Place(tick, default())
        Place(menuTick, e.menu)
        band:SetShown(e.cost ~= nil)
        if e.cost == nil then return end
        local lowSide = e.best == "lo"
        band:ClearAllPoints()
        band:SetPoint("LEFT", s, "LEFT", lowSide and 0 or X(e.cost), 0)
        band:SetPoint("RIGHT", s, "LEFT", lowSide and X(e.cost) or X(e.hi), 0)
    end
    s:SetScript("OnSizeChanged", PlaceTick)

    local refreshing = false
    s:SetScript("OnValueChanged", function(_, v)
        if refreshing then return end
        set(math.floor(v / e.step + 0.5) * e.step)
    end)

    function s:Refresh()
        refreshing = true
        self:SetValue(get() or e.lo)
        refreshing = false
        PlaceTick()
    end
    s:Refresh()
    return s
end
