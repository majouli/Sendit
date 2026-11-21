--[[
  Tiles: the group strip - one row of tiles (icon, level, level bar, name as tooltip); the picked
  tile wears the accent edge. ns.Tiles(parent, ctx) -> strip (width from its anchors)
  ctx = { Mode() -> mode, Pick(key), Picked() -> key };  strip:Refresh() / strip.height
]]
local _, ns = ...
local L = ns.L
local T = Sendit.Theme

local GAP, TILE_H = 6, 66

local function Tile(strip, group, ctx)
    local b = CreateFrame("Button", nil, strip)
    b:SetHeight(TILE_H)
    T.Fill(b, "panel", "BACKGROUND"):SetAllPoints()
    b.sel = T.Fill(b, "selected", "BACKGROUND", 1)
    b.sel:SetAllPoints()
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.edge = T.Border(b, "border")

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(group.icon)
    icon:SetSize(28, 28)
    icon:SetPoint("TOP", 0, -8)
    b.level = T.Text(b, "small", "accent")
    b.level:SetPoint("TOP", icon, "BOTTOM", 0, -4)
    b.level:SetJustifyH("CENTER")

    local track = T.Fill(b, "track", "ARTWORK")
    track:SetHeight(3)
    track:SetPoint("BOTTOMLEFT", 8, 7)
    track:SetPoint("BOTTOMRIGHT", -8, 7)
    local fill = T.Fill(b, "accent", "ARTWORK", 1)
    fill:SetHeight(3)
    fill:SetPoint("LEFT", track, "LEFT")

    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        ctx.Pick(group.key)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L[group.key], T.Color("text"))
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function b:Refresh()
        local x = ns.GroupLevel(group, ctx.Mode())
        self.level:SetText(x and ("%d %%"):format(math.floor(x * 100 + 0.5)) or "-")
        local w = (track:GetWidth() or 0) * (x or 0)
        fill:SetWidth(math.max(1, w))
        fill:SetShown(w >= 1)
        local picked = ctx.Picked() == group.key
        self.sel:SetShown(picked)
        for _, t in ipairs(self.edge) do T.Paint(t, picked and "accent" or "border") end
    end
    return b
end

function ns.Tiles(parent, ctx)
    local strip = CreateFrame("Frame", nil, parent)
    local tiles = {}
    for i, group in ipairs(ns.Catalog) do tiles[i] = Tile(strip, group, ctx) end
    strip.height = TILE_H
    strip:SetHeight(TILE_H)

    local function Place()
        local w = ((strip:GetWidth() or 0) - GAP * (#tiles - 1)) / #tiles
        for i, t in ipairs(tiles) do
            t:SetWidth(math.max(1, w))
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", (i - 1) * (w + GAP), 0)
        end
        strip:Refresh()
    end

    function strip:Refresh()
        for _, t in ipairs(tiles) do t:Refresh() end
    end
    strip:SetScript("OnSizeChanged", Place)
    Place()
    return strip
end
