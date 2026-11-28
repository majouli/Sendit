--[[
  Rows: the list's row kinds for ns.List - section heads, sets (name, kind, collected bar, its
  pieces as icons), looks (icon in its quality frame, name, type, easiest source, price or tick) and
  saved outfits. A click puts the entry on the model; shift-click links a look's item in chat.
  Rows.KINDS (for List.Create);  Rows.onPick(entry, button) is set by the window.
]]
local _, ns = ...
local L, Catalog, Collection, Sources, Browse = ns.L, ns.Catalog, ns.Collection, ns.Sources, ns.Browse
local T = Sendit.Theme
local Rows = {}
ns.Rows = Rows
local STRIP, STRIP_MAX = 20, 10
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:16:16|t"

local function Quality(q)
    local r, g, b = ns.Read(C_Item.GetItemQualityColor, q or 1)
    if type(r) ~= "number" then return 1, 1, 1 end
    return r, g, b
end

local function Icon(id)
    local it = Catalog.Item(id)
    return ns.Slots.ItemIcon(id, it and it.slot)
end

local function Base(parent)
    local r = CreateFrame("Button", nil, parent)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = T.Fill(r, "panel", "BACKGROUND")
    r.bg:SetPoint("TOPLEFT", 0, -2)
    r.bg:SetPoint("BOTTOMRIGHT", 0, 2)
    r.sel = T.Fill(r, "selected", "BACKGROUND", 1)
    r.sel:SetAllPoints(r.bg)
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints(r.bg)
    r:SetScript("OnClick", function(self, button) if Rows.onPick then Rows.onPick(self.entry, button) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function Strip(r, n)
    r.strip = r.strip or {}
    for i = #r.strip + 1, n do
        local t = r:CreateTexture(nil, "ARTWORK")
        t:SetSize(STRIP, STRIP)
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t:SetPoint("BOTTOMLEFT", 12 + (i - 1) * (STRIP + 3), 9)
        r.strip[i] = t
    end
    for i = n + 1, #r.strip do r.strip[i]:Hide() end
end

local function PaintStrip(r, ids)
    local n = math.min(#ids, STRIP_MAX)
    Strip(r, n)
    for i = 1, n do
        local t, id = r.strip[i], ids[i]
        t:SetTexture(Icon(id))
        local have = Collection.Item(id)
        t:SetDesaturated(have == false)
        t:SetVertexColor(1, 1, 1, have == false and 0.55 or 1)
        t:Show()
    end
end

local function Worn(ids)
    for _, id in ipairs(ids) do
        local it = Catalog.Item(id)
        if it and ns.Outfit.Get(it.slot) == id then return true end
    end
    return false
end

-- section head
local function HeadCreate(parent)
    local h = CreateFrame("Frame", nil, parent)
    h.text = T.Text(h, "caption", "accent")
    h.text:SetPoint("BOTTOMLEFT", 4, 6)
    h.rule = T.Fill(h, "divider", "ARTWORK")
    h.rule:SetHeight(1)
    h.rule:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
    h.rule:SetPoint("RIGHT", -4, 0)
    return h
end

local function HeadPaint(h, e) h.text:SetText((e.text or ""):upper()) end

-- set
local function SetCreate(parent)
    local r = Base(parent)
    r.name = T.Text(r, "body", "text")
    r.name:SetPoint("TOPLEFT", 12, -9)
    r.name:SetPoint("RIGHT", -90, 0)
    r.meta = T.Text(r, "small", "textMuted")
    r.meta:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.meta:SetPoint("RIGHT", -90, 0)
    r.count = T.Text(r, "label", "textDim")
    r.count:SetPoint("TOPRIGHT", -12, -10)
    r.track = T.Fill(r, "track", "ARTWORK")
    r.track:SetSize(60, 3)
    r.track:SetPoint("TOPRIGHT", r.count, "BOTTOMRIGHT", 0, -6)
    r.fill = T.Fill(r, "success", "ARTWORK", 1)
    r.fill:SetHeight(3)
    r.fill:SetPoint("LEFT", r.track, "LEFT")
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.title, 1, 1, 1)
        for _, id in ipairs(self.entry.set.items) do
            local it = Catalog.Item(id)
            local have = Collection.Item(id)
            local qr, qg, qb = Quality(it and it.q)
            GameTooltip:AddDoubleLine(Catalog.ItemName(id), have and L.collected or (have == false and L.missing or ""),
                qr, qg, qb, have and 0.4 or 0.7, have and 0.85 or 0.7, have and 0.6 or 0.7)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.hintSet, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    return r
end

local function ArmorName(kind)
    if not kind then return nil end
    return Sendit.Locale.SubClass(4, kind % 100) or ns.Read(C_Item.GetItemSubClassInfo, 4, kind % 100)
end

local function SetPaint(r, e)
    local s = e.set
    r.entry = e
    r.title = Catalog.Name("sets", s.key) or ("#" .. tostring(s.key))
    r.name:SetText(r.title)
    r.name:SetTextColor(Quality(s.q))
    r.meta:SetText(ns.Join(ArmorName(s.armor), s.kind == "transmog" and L.foreverSet or nil,
        s.ilvl > 0 and L.itemLevel:format(s.ilvl) or nil, s.lvl > 0 and L.level:format(s.lvl) or nil))
    local have, total = Collection.Count(s.items)
    r.count:SetText(("%d/%d"):format(have, total))
    T.Paint(r.count, have == total and total > 0 and "success" or "textDim")
    r.fill:SetWidth(math.max(0.01, 60 * (total > 0 and have / total or 0)))
    r.fill:SetShown(have > 0)
    r.sel:SetShown(Rows.picked == s)
    PaintStrip(r, s.items)
end

-- look
local function LookCreate(parent)
    local r = Base(parent)
    r.frame = r:CreateTexture(nil, "ARTWORK")
    r.frame:SetTexture(T.WHITE)
    r.frame:SetSize(38, 38)
    r.frame:SetPoint("LEFT", 10, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK", nil, 1)
    r.icon:SetSize(36, 36)
    r.icon:SetPoint("CENTER", r.frame)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.tick = T.Text(r, "label", "success")
    r.tick:SetPoint("TOPRIGHT", -12, -10)
    r.price = T.Text(r, "small", "textDim")
    r.price:SetPoint("BOTTOMRIGHT", -12, 10)
    r.name = T.Text(r, "body", "text")
    r.name:SetPoint("TOPLEFT", r.frame, "TOPRIGHT", 10, -2)
    r.name:SetPoint("RIGHT", r.tick, "LEFT", -8, 0)
    r.meta = T.Text(r, "small", "textMuted")
    r.meta:SetPoint("BOTTOMLEFT", r.frame, "BOTTOMRIGHT", 10, 2)
    r.meta:SetPoint("RIGHT", r.price, "LEFT", -8, 0)
    r.worn = T.Circle(r, "accent", 6, "OVERLAY")
    r.worn:SetPoint("TOPLEFT", r.frame, "TOPLEFT", -3, 3)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.item)
        local look = self.entry.look
        if #look.items > 1 then GameTooltip:AddLine(L.variants:format(#look.items - 1), 0.6, 0.6, 0.6) end
        GameTooltip:AddLine(L.hintLook, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    return r
end

local function Kind(it)
    local cls, sub = math.floor(it.kind / 100), it.kind % 100
    return Sendit.Locale.SubClass(cls, sub) or ns.Read(C_Item.GetItemSubClassInfo, cls, sub)
end

local function LookPaint(r, e)
    local look = e.look
    local id = Browse.Best(look)
    local it = Catalog.Item(id)
    r.entry, r.item = e, id
    r.icon:SetTexture(Icon(id))
    local qr, qg, qb = Quality(it and it.q)
    r.frame:SetVertexColor(qr, qg, qb, 0.9)
    r.name:SetText(Catalog.ItemName(id) .. (#look.items > 1 and ("  |cff8a8f9e+" .. (#look.items - 1) .. "|r") or ""))
    r.name:SetTextColor(qr, qg, qb)
    local first = Sources.ForLook(look)[1]
    local kind = Kind(it)
    r.meta:SetText(ns.Join(kind, first and first.title or L.sourceUnknown))
    local have = Collection.Look(look)
    r.tick:SetText(have and TICK or "")
    local price = not have and Sources.Price(look)
    r.price:SetText(price and Sources.Money(price) or "")
    r.icon:SetDesaturated(have == false and not price and first == nil)
    r.worn:SetShown(Worn(look.items))
    r.sel:SetShown(false)
end

-- saved outfit
local function OutfitPaint(r, e)
    local o = e.outfit
    r.entry = e
    r.title = o.name
    r.name:SetText(o.name)
    r.name:SetTextColor(1, 1, 1)
    local ids = {}
    for _, slot in ipairs(ns.Slots.ORDER) do
        local id = type(o.items) == "table" and o.items[slot]
        if type(id) == "number" and Catalog.Item(id) then ids[#ids + 1] = id end
    end
    local have, total = Collection.Count(ids)
    r.meta:SetText(L.pieces:format(#ids))
    r.count:SetText(("%d/%d"):format(have, total))
    T.Paint(r.count, have == total and total > 0 and "success" or "textDim")
    r.fill:SetWidth(math.max(0.01, 60 * (total > 0 and have / total or 0)))
    r.fill:SetShown(have > 0)
    r.sel:SetShown(ns.Outfit.Name() == o.name)
    PaintStrip(r, ids)
end

local function OutfitCreate(parent)
    local r = SetCreate(parent)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.title, 1, 1, 1)
        GameTooltip:AddLine(L.hintOutfit, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    return r
end

Rows.KINDS = {
    head = { height = 30, create = HeadCreate, paint = HeadPaint },
    set = { height = 70, create = SetCreate, paint = SetPaint },
    look = { height = 52, create = LookCreate, paint = LookPaint },
    outfit = { height = 70, create = OutfitCreate, paint = OutfitPaint },
}
