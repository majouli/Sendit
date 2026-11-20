--[[
  DungeonRow: one dungeon in the list - loading-screen thumbnail, name, level pill (green when it
  fits), kind / size / bosses, and while the boost runs its best upgrade with a gold edge - or,
  without one, dimmed with "no upgrade".
  DungeonRow.Create(parent, onPick) -> row;  DungeonRow.Paint(row, d, width, selected)
]]
local _, ns = ...
local T, S, DB = Sendit.Theme, ns.Style, ns.Database
local Row = {}
ns.DungeonRow = Row

function Row.Create(parent, onPick)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(S.size.row)
    r.bg = T.Fill(r, S.surface.row, "BACKGROUND")
    r.bg:SetAllPoints()
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    r.edge = T.Fill(r, "accent", "ARTWORK")
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(3)
    r.thumb = r:CreateTexture(nil, "ARTWORK")
    r.thumb:SetSize(S.size.row - 16, S.size.row - 16)
    r.thumb:SetPoint("LEFT", 10, 0)
    r.name = T.Text(r, S.font.name, "text")
    r.name:SetPoint("TOPLEFT", S.size.row + 2, -9)
    r.name:SetJustifyH("LEFT")
    r.level = T.Text(r, S.font.caption, "textDim")
    r.level:SetPoint("TOPRIGHT", -12, -10)
    r.meta = T.Text(r, S.font.meta, "textMuted")
    r.meta:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
    r.meta:SetJustifyH("LEFT")
    r.boost = T.Text(r, S.font.meta, "accent")
    r.boost:SetPoint("TOPLEFT", r.meta, "BOTTOMLEFT", 0, -3)
    r.boost:SetJustifyH("LEFT")
    r:SetScript("OnClick", function(self) onPick(self.id) end)
    return r
end

function Row.Paint(r, d, width, selected)
    r.id = d.id
    r:SetWidth(width)
    T.Paint(r.bg, selected and S.surface.rowSelected or S.surface.row)
    ns.Art.Thumb(r.thumb, d)
    local b = ns.Boost.Get(d.id)
    local dim = ns.Boost.Active() and not b
    r.thumb:SetDesaturated(dim)
    r.name:SetWidth(width - 110 - S.size.row)
    r.name:SetText(DB.Name(d))
    T.Paint(r.name, selected and "accent" or dim and "textDim" or "text")
    local fit = DB.Fit(d, DB.Level())
    r.level:SetText(d.min > 0 and ns.L.levels:format(d.min, d.max) or ns.L.levelUnknown)
    T.Paint(r.level, S.FitRole(fit))
    local parts = { DB.Kind(d) }
    if d.players > 0 and d.raid and d.map ~= 0 then parts[#parts + 1] = ns.L.players:format(d.players) end
    parts[#parts + 1] = ns.L.bosses:format(#d.bosses)
    r.meta:SetText(table.concat(parts, "  ·  "))
    r.meta:SetWidth(width - 28 - S.size.row)
    r.boost:SetShown(b ~= nil or dim)
    r.edge:SetShown(b ~= nil or selected)
    T.Paint(r.edge, "accent", b and 1 or 0.45)
    if b then
        local extra = b.count > 1 and ("  ·  " .. ns.L.upgrades:format(b.count)) or ""
        r.boost:SetText(S.Upgrade(b) .. extra)
    elseif dim then
        r.boost:SetText(ns.L.noUpgrade)
    end
    T.Paint(r.boost, b and "accent" or "textMuted")
    r.boost:SetWidth(width - 28 - S.size.row)
    r:Show()
end
