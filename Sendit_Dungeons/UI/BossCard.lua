--[[
  BossCard: one boss of the picked dungeon - round portrait (hover: 3D model), order number, name,
  its drops as a loot grid; upgrades lead the grid and pulse gold, the best gain shows by the name. "Loot unknown" /
  "world drops only" instead of an empty card; a rare spawn says so by its number.
  BossCard.Create(parent) -> card;  card:Set(index, boss, width) -> height
]]
local _, ns = ...
local T, S, DB = Sendit.Theme, ns.Style, ns.Database
local Card = {}
ns.BossCard = Card
local HEAD = 58
local PORTRAIT = 42

function Card.Create(parent)
    local c = CreateFrame("Frame", nil, parent)
    T.Fill(c, S.surface.card, "BACKGROUND"):SetAllPoints()
    c.edges = T.Border(c, "border")
    c.edge = T.Fill(c, "accent", "ARTWORK")
    c.edge:SetPoint("TOPLEFT")
    c.edge:SetPoint("BOTTOMLEFT")
    c.edge:SetWidth(3)
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
        self.number:SetText(boss.drops and "" or (("%02d"):format(index) .. (boss.rare and ("  ·  " .. ns.L.rare) or "")))
        self.name:SetText(DB.BossName(boss))
        local loot = DB.Loot(boss)
        -- boost rated: upgrades first, the biggest gain leading; the rest keeps its order (not while
        -- items are still rated: icons would jump with every batch)
        local sort = ns.Boost.Active() and not select(3, ns.Boost.Progress())
        local gain = {}
        for i, drop in ipairs(loot) do
            local r = ns.Boost.Item(drop[1])
            gain[drop] = r and r.pct or -1
            drop.order = i
        end
        if sort then table.sort(loot, function(a, b)
            if gain[a] ~= gain[b] then return gain[a] > gain[b] end
            return a.order < b.order
        end) end
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
