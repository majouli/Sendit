--[[
  Page: the Graphics page in the Sendit window - the head card (Hero), the group tiles (Tiles) and the
  picked group's card (Detail); head and tiles stay, only the card scrolls. Mode (World / Raid) and the picked group live here.
  The search finds every CVar row; Reveal picks its group first.
]]
local _, ns = ...
local L = ns.L

local O, W, T = Sendit.Options, Sendit.Widgets, Sendit.Theme
local SIZE = T.SIZE
local function Tx(key) return Sendit.Locale.Text(L, key) end

local GAP = 12

local function Build(frame)
    local page = { mode = "normal", picked = ns.Catalog[1].key }
    local hero, tiles, detail
    local ctx = {
        Mode = function() return page.mode end,
        Picked = function() return page.picked end,
    }
    function ctx.Changed() page:Refresh() end
    function ctx.SetMode(mode)
        page.mode = mode
        page:Refresh()
    end

    hero = ns.Hero(frame, ctx)
    hero:SetPoint("TOPLEFT", SIZE.pad, -24)
    hero:SetPoint("RIGHT", -SIZE.pad, 0)
    tiles = ns.Tiles(frame, ctx)
    tiles:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -GAP)
    tiles:SetPoint("RIGHT", hero, "RIGHT")

    local area = W.ScrollArea(frame)
    area:SetPoint("TOPLEFT", tiles, "BOTTOMLEFT", 0, -GAP)
    area:SetPoint("BOTTOMRIGHT", -SIZE.pad, 0)
    local content = area.content
    content:SetWidth(SIZE.width - SIZE.sidebar - SIZE.pad * 2)
    detail = ns.Detail(content, ctx)
    detail:SetPoint("TOPLEFT")
    detail:SetPoint("RIGHT")
    local note = T.Text(content, "small", "textMuted")
    note:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 2, -10)
    note:SetPoint("RIGHT", -2, 0)
    note:SetWordWrap(true)
    page.entries = detail.entries

    function ctx.Pick(key)
        page.picked = key
        detail:Show(key)
        area:SetVerticalScroll(0)
        page:Refresh()
    end
    detail:Show(page.picked)

    local flash = W.Layout(content)  -- its Reveal: scroll + wash

    function page:Refresh()
        hero:Refresh()
        tiles:Refresh()
        detail:Refresh()
        detail:SetHeight(math.max(1, detail:Height()))
        note:SetText(L.note)
        content:SetHeight(detail:Height() + 10 + (note:GetStringHeight() or 14) + GAP)
    end

    function page:Reveal(row)
        if row.group ~= self.picked then ctx.Pick(row.group) end
        row.top = row.cardTop
        flash:Reveal(row)
    end
    return page
end

O:Register({
    key = "graphics",
    module = ns.module,
    title = Tx("title"),
    subtitle = Tx("subtitle"),
    resetKeys = { "normal", "raid" },
    onReset = function() ns.CVars.ResetAll() end,
    build = Build,
})
