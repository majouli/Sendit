--[[
  RewardView: the reward section of an opened step - "You receive", "Choose one", then XP and
  money; whole tiles show the item tooltip; unsent values stay "not known yet".
  RewardView.Create(parent) -> frame;  RewardView.Render(frame, width, data) -> height
]]
local _, ns = ...
local T, S, L = Sendit.Theme, ns.Style, ns.L
local View = {}
ns.RewardView = View
local TILE_W, TILE_H, TILE_GAP = 190, 40, 6

function View.Create(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.labels, f.tiles = {}, {}
    return f
end

local function Tile(f, i)
    local t = f.tiles[i]
    if t then return t end
    t = CreateFrame("Button", nil, f)
    t:SetHeight(TILE_H)
    -- the whole tile shows the item tooltip
    t:SetScript("OnEnter", function(self) self.icon:GetScript("OnEnter")(self.icon) end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t.bg = T.Fill(t, "selected", "BACKGROUND")
    t.bg:SetAllPoints()
    T.Fill(t, "hover", "HIGHLIGHT"):SetAllPoints()
    t.icon = ns.RewardIcon.Create(t, S.size.iconBig)
    t.icon:SetPoint("LEFT", 3, 0)
    t.name = T.Text(t, "small", "text")
    t.name:SetPoint("LEFT", t.icon, "RIGHT", 8, 0)
    t.name:SetPoint("RIGHT", -6, 0)
    t.name:SetWordWrap(true)
    t.name:SetMaxLines(2)
    f.tiles[i] = t
    return t
end

local function Paint(name, itemID)
    local _, _, quality = ns.RewardIcon.Info(itemID)
    local colors = _G["ITEM_QUALITY_COLORS"]
    local c = quality and colors and colors[quality]
    if c then
        T.Own(name)
        name:SetTextColor(c.r, c.g, c.b, 1)
    else
        T.Paint(name, "text")
    end
end

function View.Render(f, width, data)
    local y, labels, tiles = 0, 0, 0
    local function Label(text, role, font)
        labels = labels + 1
        local t = f.labels[labels] or T.Text(f, font or S.font.section, role)
        f.labels[labels] = t
        T.SetFont(t, font == "small" and 11 or 12)
        T.Paint(t, role)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 0, -y)
        t:SetWidth(width)
        t:SetWordWrap(true)
        t:SetText(text)
        t:Show()
        y = y + t:GetStringHeight() + 6
    end
    local function Tiles(list, choice)
        local cols = math.max(1, math.floor((width + TILE_GAP) / (TILE_W + TILE_GAP)))
        local w = (width - (cols - 1) * TILE_GAP) / cols
        for i, item in ipairs(list) do
            tiles = tiles + 1
            local t = Tile(f, tiles)
            t.icon:Set(item.itemId, item.amount, choice)
            local name = ns.RewardIcon.Info(item.itemId)
            t.name:SetText(name or ("#" .. item.itemId))
            Paint(t.name, item.itemId)
            t:SetWidth(w)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", ((i - 1) % cols) * (w + TILE_GAP), -y - math.floor((i - 1) / cols) * (TILE_H + TILE_GAP))
            t:Show()
        end
        y = y + math.ceil(#list / cols) * (TILE_H + TILE_GAP) + 4
    end
    if #data.items > 0 then Label(L.fixedRewards, "textDim") Tiles(data.items, false) end
    if #data.choices > 0 then Label(L.chooseReward, "accent") Tiles(data.choices, true) end
    local parts = {}
    local xp, money = S.XP(data.xp), S.Money(data.money)
    if xp then parts[#parts + 1] = xp end
    if money then parts[#parts + 1] = money end
    if #parts > 0 then Label(table.concat(parts, "   "), "text", "small")
    elseif data.xp == nil or data.money == nil then Label(L.valuesPending, "textMuted", "small") end
    for i = labels + 1, #f.labels do f.labels[i]:Hide() end
    for i = tiles + 1, #f.tiles do f.tiles[i]:Hide() end
    f:SetSize(width, math.max(1, y))
    f:SetShown(y > 0)
    return y
end
