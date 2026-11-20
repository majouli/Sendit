--[[
  Hero: the head bar - overall level (big number + bar), World / Raid switch, the client's own raid
  values switch and the two presets (client default, Maximum) for the shown mode.
  ns.Hero(parent, ctx) -> hero;  ctx = { Mode(), SetMode(mode), Changed() };  hero:Refresh() / .height
]]
local _, ns = ...
local L = ns.L
local T, W = Sendit.Theme, Sendit.Widgets
local CVars = ns.CVars
local function Tx(key) return Sendit.Locale.Text(L, key) end

local RAID_SWITCH = "RAIDsettingsEnabled"
local PAD, BAR_W = 18, 150

local function Maximum(mode)
    for _, e in pairs(ns.byCvar) do
        local v = ns.Best(e)
        if v ~= nil then CVars.Set(e, mode, v) end
    end
end

local function ClientDefaults(mode)
    for _, e in pairs(ns.byCvar) do CVars.Reset(e, mode) end
end

function ns.Hero(parent, ctx)
    local h = CreateFrame("Frame", nil, parent)
    h.height = 84
    h:SetHeight(h.height)
    local sky = T.Fill(h, "sky", "BACKGROUND")
    sky:SetAllPoints()
    T.Gradient(sky, "sky", "panel")
    T.Border(h, "border")

    local caption = T.Text(h, "caption", "textMuted")
    caption:SetPoint("TOPLEFT", PAD, -14)
    local level = T.Text(h, "hero", "accent")
    level:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -4)
    local track = T.Fill(h, "track", "ARTWORK")
    track:SetSize(BAR_W, 5)
    track:SetPoint("BOTTOMLEFT", PAD, 14)
    local fill = T.Fill(h, "accent", "ARTWORK", 1)
    fill:SetHeight(5)
    fill:SetPoint("LEFT", track, "LEFT")

    local max = W.Button(h, "", function()
        Maximum(ctx.Mode())
        ctx.Changed()
    end, "primary")
    max:SetPoint("TOPRIGHT", -PAD, -12)
    local client = W.Button(h, "", function()
        ClientDefaults(ctx.Mode())
        ctx.Changed()
    end)
    client:SetPoint("RIGHT", max, "LEFT", -8, 0)

    local modes = W.Segmented(h, { { "normal", Tx("world") }, { "raid", Tx("raid") } }, ctx.Mode, ctx.SetMode)
    modes:SetPoint("BOTTOMRIGHT", -PAD, 12)
    local raidOwn = W.Switch(h, function() return CVars.Raw(RAID_SWITCH) == "1" end,
        function(on) CVars.Write(RAID_SWITCH, on and 1 or 0) end)
    raidOwn:SetPoint("RIGHT", modes, "LEFT", -18, 0)
    local raidLabel = T.Text(h, "label", "textDim")
    raidLabel:SetPoint("RIGHT", raidOwn, "LEFT", -8, 0)

    function h:Refresh()
        caption:SetText(L.total:upper())
        local x = ns.TotalLevel(ctx.Mode())
        level:SetText(x and ("%d %%"):format(math.floor(x * 100 + 0.5)) or "-")
        fill:SetWidth(math.max(1, BAR_W * (x or 0)))
        modes:Refresh()
        raidOwn:Refresh()
        raidLabel:SetText(L.raidOwn)
        max:SetLabel(L.presetMax)
        client:SetLabel(L.presetClient)
    end
    return h
end
