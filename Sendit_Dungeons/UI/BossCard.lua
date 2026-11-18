--[[
  BossCard: one boss of the picked dungeon - its round portrait (hover: the
  3D model, UI/Art.lua), its number in the dungeon's order, its name, and what it drops as a grid of loot icons (drop chance
  below each; upgrades glow gold while the gear boost runs). A boss with
  an upgrade gets a gold edge and its best gain right of the name. Bosses
  without loot data say so ("loot unknown"), bosses that drop nothing of
  their own say "world drops only" - never an empty card.

  BossCard.Create(parent) -> card
  card:Set(index, boss, width) -> height the card needs at that width
]]
local _, ns = ...
local T, S, DB = Sendit.Theme, ns.Style, ns.Database
local Card = {}
ns.BossCard = Card
local HEAD = 58     -- portrait row; the loot grid starts below it
local PORTRAIT = 42

function Card.Create(parent)
    local c = CreateFrame("Frame", nil, parent)
    T.Fill(c, S.surface.card, "BACKGROUND"):SetAllPoints()
    c.edges = T.Border(c, "border")
    c.edge = T.Fill(c, "accent", "ARTWORK")
    c.edge:SetPoint("TOPLEFT")
    c.edge:SetPoint("BOTTOMLEFT")
    c.edge:SetWidth(3)
    -- the boss's round portrait; hover: the 3D model (UI/Art.lua)
    local face = CreateFrame("Frame", nil, c)
    face:SetSize(PORTRAIT, PORTRAIT)
    face:SetPoint("TOPLEFT", S.space.card + 2, -8)
    T.Circle(face, "border", PORTRAIT + 2, "BACKGROUND"):SetPoint("CENTER")
    c.portrait = face:CreateTexture(nil, "ARTWORK")
    c.portrait:SetAllPoints()
    pcall(c.portrait.SetMask, c.portrait, ns.Art.MASK)
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, face)
    if ok and model then
        model:SetAllPoints()
        model:Hide()
        ns.Art.Still(model)
        c.face = model
    end
    face:EnableMouse(true)
    face:SetScript("OnEnter", function() if c.boss then ns.Art.ShowModel(face, c.boss) end end)
    face:SetScript("OnLeave", function() ns.Art.HideModel() end)
    c.number = T.Text(c, S.font.caption, "textMuted")
    c.number:SetPoint("TOPLEFT", face, "TOPRIGHT", 10, -4)
    c.name = T.Text(c, S.font.section, "text")
    c.name:SetPoint("TOPLEFT", c.number, "BOTTOMLEFT", 0, -4)
    c.name:SetJustifyH("LEFT")
    c.best = T.Text(c, S.font.meta, "accent")
    c.best:SetPoint("TOPRIGHT", -S.space.card, -10)
    c.none = T.Text(c, S.font.meta, "textMuted")
    c.none:SetPoint("TOPLEFT", S.space.card + 2, -HEAD)
    c.none:SetJustifyH("LEFT")
    c.none:SetWordWrap(true)
    c.icons = {}
    function c:Set(index, boss, width)
        self:SetWidth(width)
        self.boss = boss
        ns.Art.Portrait(self.portrait, boss, self.face)
        self.number:SetText(("%02d"):format(index))
        self.name:SetText(DB.BossName(boss))
        local loot = DB.Loot(boss)
        local perRow = math.max(1, math.floor((width - 2 * S.space.card + S.size.iconGap) / (ns.LootIcon.WIDTH + S.size.iconGap)))
        local best
        for i, drop in ipairs(loot) do
            local icon = self.icons[i] or ns.LootIcon.Create(self)
            self.icons[i] = icon
            local col, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", S.space.card + 2 + col * (ns.LootIcon.WIDTH + S.size.iconGap),
                -HEAD - line * (ns.LootIcon.HEIGHT + 6))
            icon:Set(drop[1], drop[2])
            local r = ns.Boost.Item(drop[1])
            if r and (not best or r.pct > best.pct) then best = r end
        end
        for i = #loot + 1, #self.icons do self.icons[i]:Hide() end
        self.none:SetShown(#loot == 0)
        self.none:SetWidth(width - 2 * S.space.card)
        self.none:SetText(boss.known and ns.L.worldOnly or ns.L.lootUnknown)
        self.best:SetShown(best ~= nil)
        if best then self.best:SetText(S.Upgrade(best)) end
        self.name:SetWidth(width - 90 - PORTRAIT - (best and self.best:GetStringWidth() + 12 or 0))
        self.edge:SetShown(best ~= nil)
        for _, e in ipairs(self.edges) do T.Paint(e, best and "accent" or "border", best and 0.5 or nil) end
        local lines = #loot > 0 and math.ceil(#loot / perRow) or 0
        local h = HEAD + (lines > 0 and lines * (ns.LootIcon.HEIGHT + 6) or (self.none:GetStringHeight() + 8)) + 6
        self:SetHeight(h)
        self:Show()
        return h
    end
    return c
end
