--[[
  Pieces: the outfit panel - every worn piece with its slot, whether its look is collected and the
  easiest ways to get it (up to three, the rest in a tooltip). A source with a place sets a map pin,
  a quest / dungeon opens Sendit Quests / Dungeons there. Summary on top: collected and what the
  missing pieces cost on the auction house.
  Pieces.Create(parent) -> panel;  panel:Refresh()
]]
local _, ns = ...
local L, Catalog, Collection, Sources, Outfit, Slots = ns.L, ns.Catalog, ns.Collection, ns.Sources, ns.Outfit, ns.Slots
local T, W = Sendit.Theme, Sendit.Widgets
local Pieces = {}
ns.Pieces = Pieces
local HEAD, LINE, SHOWN, GAP = 46, 22, 3, 10
local TITLE_SHARE = 0.6  -- a long source name leaves the rest of the line to its details

local function Quality(q)
    local r, g, b = ns.Read(C_Item.GetItemQualityColor, q or 1)
    if type(r) ~= "number" then return 1, 1, 1 end
    return r, g, b
end

local function SourceTip(owner, list, from)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(L.moreSources, 1, 1, 1)
    for i = from, #list do
        local e = list[i]
        GameTooltip:AddDoubleLine(e.title, e.detail, 1, 0.82, 0, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function Line(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(LINE)
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 6, 0)
    b.title = T.Text(b, "label", "text")
    b.title:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
    b.go = T.Text(b, "small", "accent")
    b.go:SetPoint("RIGHT", -6, 0)
    b.detail = T.Text(b, "small", "textMuted")
    b.detail:SetPoint("LEFT", b.title, "RIGHT", 8, 0)
    b.detail:SetPoint("RIGHT", b.go, "LEFT", -6, 0)
    b:SetScript("OnClick", function(self)
        if self.entry and self.entry.action then self.entry.action() end
    end)
    b:SetScript("OnEnter", function(self)
        local e = self.entry
        if self.more then SourceTip(self, self.more, self.moreFrom) return end
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(e.title, 1, 1, 1)
        GameTooltip:AddLine(e.detail, 0.75, 0.75, 0.75, true)
        if e.item and Catalog.ItemName(e.item) then GameTooltip:AddLine(Catalog.ItemName(e.item), 0.6, 0.6, 0.6) end
        if e.hint then GameTooltip:AddLine(e.hint, 0.9, 0.73, 0.4) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function Block(parent)
    local f = CreateFrame("Frame", nil, parent)
    T.Fill(f, "panel", "BACKGROUND"):SetAllPoints()
    f.head = CreateFrame("Button", nil, f)
    f.head:SetPoint("TOPLEFT")
    f.head:SetPoint("TOPRIGHT")
    f.head:SetHeight(HEAD)
    f.head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.frame = f.head:CreateTexture(nil, "ARTWORK")
    f.frame:SetTexture(T.WHITE)
    f.frame:SetSize(36, 36)
    f.frame:SetPoint("LEFT", 8, 0)
    f.icon = f.head:CreateTexture(nil, "ARTWORK", nil, 1)
    f.icon:SetSize(34, 34)
    f.icon:SetPoint("CENTER", f.frame)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.slot = T.Text(f.head, "caption", "textMuted")
    f.slot:SetPoint("TOPLEFT", f.frame, "TOPRIGHT", 10, -2)
    f.state = T.Text(f.head, "caption", "success")
    f.state:SetPoint("LEFT", f.slot, "RIGHT", 8, 0)
    f.name = T.Text(f.head, "body", "text")
    f.name:SetPoint("BOTTOMLEFT", f.frame, "BOTTOMRIGHT", 10, 2)
    f.name:SetPoint("RIGHT", -34, 0)
    f.remove = W.Close(f.head, function() Outfit.Clear(f.key) end)
    f.remove:SetPoint("TOPRIGHT", -6, -6)
    f.remove:SetScale(0.8)
    f.head:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        pcall(GameTooltip.SetItemByID, GameTooltip, f.item)
        GameTooltip:Show()
    end)
    f.head:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.head:SetScript("OnClick", function(_, button)
        if button == "RightButton" then Outfit.Clear(f.key) return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local _, link = ns.Read(C_Item.GetItemInfo, f.item)
            local insert = _G["ChatEdit_InsertLink"]
            if link and insert then insert(link) end
        end
    end)
    f.lines = {}
    return f
end

local function Fill(f, key, id, width)
    local it = Catalog.Item(id)
    local look = Catalog.LookOf(id)
    f.key, f.item = key, id
    f.icon:SetTexture(Slots.ItemIcon(id, key))
    local qr, qg, qb = Quality(it and it.q)
    f.frame:SetVertexColor(qr, qg, qb, 0.9)
    f.slot:SetText(Slots.Name(key):upper())
    local have = look and Collection.Look(look)
    f.state:SetText(have and L.collected or (have == false and L.missing or ""))
    T.Paint(f.state, have and "success" or "warning")
    f.name:SetText(Catalog.ItemName(id))
    f.name:SetTextColor(qr, qg, qb)
    local list = look and Sources.ForLook(look) or {}
    local n = math.min(#list, SHOWN)
    local rows = n + ((#list > SHOWN) and 1 or 0) + ((#list == 0) and 1 or 0)
    for i = 1, rows do
        local b = f.lines[i] or Line(f)
        f.lines[i] = b
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 6, -(HEAD + (i - 1) * LINE))
        b:SetWidth(width - 12)
        b.more, b.entry = nil, nil
        local e = list[i]
        if e and i <= SHOWN then
            b.entry = e
            b.icon:SetTexture(e.icon)
            b.icon:Show()
            b.title:SetText(e.title)
            b.title:SetWidth(math.min(b.title:GetStringWidth() + 2, (width - 12) * TITLE_SHARE))
            b.detail:SetText(e.detail or "")
            b.go:SetText(e.action and ">" or "")
            T.Paint(b.title, e.off and "textMuted" or "text")
            b:SetAlpha(e.off and 0.6 or 1)
        elseif #list == 0 then
            b.icon:Hide()
            b.title:SetText(L.sourceUnknown)
            b.title:SetWidth(b.title:GetStringWidth() + 2)
            b.detail:SetText("")
            b.go:SetText("")
            T.Paint(b.title, "textMuted")
            b:SetAlpha(1)
        else
            b.icon:Hide()
            b.title:SetText(L.moreCount:format(#list - SHOWN))
            b.title:SetWidth(b.title:GetStringWidth() + 2)
            b.detail:SetText("")
            b.go:SetText("")
            T.Paint(b.title, "accent")
            b.more, b.moreFrom = list, SHOWN + 1
            b:SetAlpha(1)
        end
        b:Show()
    end
    for i = rows + 1, #f.lines do f.lines[i]:Hide() end
    local height = HEAD + rows * LINE + 8
    f:SetSize(width, height)
    return height
end

function Pieces.Create(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel.title = T.Text(panel, "heading", "text")
    panel.title:SetPoint("TOPLEFT", 4, -2)
    panel.title:SetPoint("RIGHT", -4, 0)
    panel.summary = T.Text(panel, "small", "textDim")
    panel.summary:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -5)
    panel.summary:SetPoint("RIGHT", -4, 0)
    panel.summary:SetWordWrap(true)
    panel.scroll = W.ScrollArea(panel)
    panel.scroll:SetPoint("TOPLEFT", 0, -46)
    panel.scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.empty = T.Text(panel.scroll.content, "body", "textMuted")
    panel.empty:SetPoint("TOPLEFT", 4, -8)
    panel.empty:SetPoint("RIGHT", -4, 0)
    panel.empty:SetWordWrap(true)
    panel.empty:SetJustifyV("TOP")
    panel.empty:SetHeight(80)
    local blocks = {}

    function panel:Refresh()
        local items = Outfit.Items()
        self.title:SetText(Outfit.Name() or L.outfit)
        local width = self.scroll:GetWidth()
        if not width or width < 50 then width = 320 end
        local y, used, ids, missing, cost, buyable = 0, 0, {}, 0, 0, 0
        for _, key in ipairs(Slots.ORDER) do
            local id = items[key]
            if id then
                used = used + 1
                ids[#ids + 1] = id
                local f = blocks[used] or Block(self.scroll.content)
                blocks[used] = f
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", 0, -y)
                y = y + Fill(f, key, id, width) + GAP
                f:Show()
                local look = Catalog.LookOf(id)
                if look and Collection.Look(look) ~= true then
                    missing = missing + 1
                    local price = Sources.Price(look)
                    if price then cost, buyable = cost + price, buyable + 1 end
                end
            end
        end
        for i = used + 1, #blocks do blocks[i]:Hide() end
        self.empty:SetShown(used == 0)
        self.empty:SetText(L.outfitEmpty)
        self.scroll.content:SetHeight(math.max(1, y))
        local have, total = Collection.Count(ids)
        local text = used == 0 and "" or L.summary:format(have, total)
        if buyable > 0 then text = text .. "  ·  " .. L.summaryCost:format(buyable, Sources.Money(cost)) end
        if missing == 0 and used > 0 then text = text .. "  ·  " .. L.summaryDone end
        self.summary:SetText(text)
    end
    return panel
end
