--[[
  Window: beside the merchant window, every bag item as a tile (like the bags) under what to do with it -
  merchant, auction house, materials, disenchant, useful, no auction price, keep. A section's head ticks all its items
  (box), shows count and value and folds it (click); a tile ticks one item (left click; ticked tiles carry a
  check, the others are pale) or marks it to keep (right click, Sendit_SellCharDB.keep). Anything the
  merchant pays for can be ticked, kept items too. Ticked by default: the merchant section only - useful,
  materials, auction house, disenchant and kept items are never sold unasked.
  "keep" starts folded. The foot shows what is ticked, its merchant total, and sells it. Ticks last one
  visit. Opens with the merchant (profile autoOpen), closes with it; /sell toggles it there.
  Window.Open() / Hide() / Toggle() / Shown() / Refresh()
]]
local _, ns = ...
local L = ns.L
local T, W = Sendit.Theme, Sendit.Widgets
local Advice, Seller, Money = ns.Advice, ns.Seller, ns.Money
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT, PAD, HEADER, FOOTER, HEAD_ROW, TILE, GAP, REPAINT = 480, 620, 16, 60, 58, 34, 42, 6, 0.3
local ORDER = { "vendor", "ah", "mats", "de", "use", "unknown", "keep" }
local DEFAULT_ON = { vendor = true }
local CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local frame
local tiles, heads = {}, {}
local sectionOn, picked = {}, {}  -- section key -> ticked; "bag:slot:link" -> ticked (overrides the section)
local folded = { keep = true }

local function Key(e) return e.bag .. ":" .. e.slot .. ":" .. e.link end
local function Sellable(e) return e.action ~= "loading" and (e.vendor or 0) > 0 end

local function Ticked(e)
    if not Sellable(e) then return false end
    local own = picked[Key(e)]
    if own ~= nil then return own end
    return sectionOn[e.action] == true
end

local function ResetTicks()
    sectionOn, picked = {}, {}
    for key, on in pairs(DEFAULT_ON) do sectionOn[key] = on end
end
ResetTicks()

local function QualityColor(q)
    local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q or 1)
    if ok and type(r) == "number" then return r, g, b end
    return 0.6, 0.6, 0.6
end

local function Tooltip(self)
    local e = self.e
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(e.bag, e.slot)
    if e.reason then GameTooltip:AddLine(e.reason, 1, 0.82, 0) end
    GameTooltip:AddLine(L.tipWhy:format(Money(e.vendor or 0), e.ah and Money(e.ah) or "-"), 0.8, 0.8, 0.8)
    if e.de then GameTooltip:AddLine(L.deLine:format(Money(e.de)), 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(Sellable(e) and L.tipTile or L.tipKeep, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function Tile(i)
    local t = tiles[i]
    if t then return t end
    t = CreateFrame("Button", nil, frame.list.content)
    t:SetSize(TILE, TILE)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetPoint("TOPLEFT", 2, -2)
    t.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    t.edges = {}
    for n, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
                         { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = t:CreateTexture(nil, "BORDER")
        edge:SetPoint(p[1])
        edge:SetPoint(p[2])
        if n <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
        t.edges[n] = edge
    end
    T.Fill(t, "hover", "HIGHLIGHT"):SetAllPoints()
    t.count = T.Text(t, "small", "text")
    t.count:SetPoint("BOTTOMRIGHT", -3, 3)
    t.check = t:CreateTexture(nil, "OVERLAY")
    t.check:SetTexture(CHECK)
    t.check:SetSize(16, 16)
    t.check:SetPoint("TOPRIGHT", 3, 3)
    t:SetScript("OnClick", function(self, button)
        local e = self.e
        if not e then return end
        if button == "RightButton" then
            if ns.charDB then ns.charDB.keep[e.itemID] = not ns.charDB.keep[e.itemID] or nil end
        elseif Sellable(e) then
            picked[Key(e)] = not Ticked(e)
        end
        Window.Refresh()
        Tooltip(self)
    end)
    t:SetScript("OnEnter", Tooltip)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tiles[i] = t
    return t
end

local function Head(i)
    local h = heads[i]
    if h then return h end
    h = CreateFrame("Button", nil, frame.list.content)
    h:SetHeight(HEAD_ROW)
    T.Fill(h, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Fill(h, "hover", "HIGHLIGHT"):SetAllPoints()
    h.check = W.Check(h, function(_, on)
        if not h.key then return end
        sectionOn[h.key] = on
        for _, e in ipairs(h.items or {}) do picked[Key(e)] = nil end
        Window.Refresh()
    end)
    h.check:SetPoint("LEFT", 10, 0)
    h.chevron = W.Chevron(h, "textDim", "down")
    h.chevron:SetPoint("RIGHT", -12, 0)
    h.text = T.Text(h, "caption", "accent")
    h.text:SetPoint("LEFT", 34, 0)
    h.sum = T.Text(h, "label", "text")
    h.sum:SetPoint("RIGHT", h.chevron, "LEFT", -12, 0)
    h:SetScript("OnClick", function(self)
        if not self.key then return end
        folded[self.key] = not folded[self.key] or nil
        Window.Refresh()
    end)
    heads[i] = h
    return h
end

local function PaintTile(t, e, x, y)
    t.e = e
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", x, -y)
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(e.itemID)
    t.icon:SetTexture(icon or 134400)
    t.count:SetText(e.count > 1 and e.count or "")
    local r, g, b = QualityColor(e.quality)
    for _, edge in ipairs(t.edges) do edge:SetColorTexture(r, g, b, 0.9) end
    local on = Ticked(e)
    t.check:SetShown(on)
    local pale = Sellable(e) and not on
    t.icon:SetDesaturated(pale)
    t:SetAlpha(pale and 0.45 or 1)
    t:Show()
end

local function PaintHead(h, key, list, y, width)
    h.key, h.items = key, list
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, -y)
    h:SetWidth(width)
    h.text:SetText(L[key]:upper() .. "  |cff8a8a8a" .. #list .. "|r")
    local sum, ticked, sellable = 0, 0, 0
    for _, e in ipairs(list) do
        local worth = key == "ah" and e.ah or key == "de" and e.de
            or key == "mats" and math.max(e.ah or 0, e.vendor or 0) or e.vendor
        sum = sum + (worth or 0)
        if Ticked(e) then ticked = ticked + 1 end
        if Sellable(e) then sellable = sellable + 1 end
    end
    h.sum:SetText(Money(sum))
    h.check:SetShown(sellable > 0)
    h.check:Set(ticked > 0)
    h.check:SetAlpha(ticked > 0 and ticked < sellable and 0.5 or 1)
    h.chevron:Point(folded[key] and "right" or "down")
    h:Show()
end

function Window.Refresh()
    if not frame or not frame:IsShown() then return end
    local groups = {}
    for _, key in ipairs(ORDER) do groups[key] = {} end
    for _, e in ipairs(Advice.Bags()) do
        local list = groups[e.action == "loading" and "unknown" or e.action]
        if list then list[#list + 1] = e end
    end
    local width = WIDTH - 2 * PAD
    local cols = math.max(1, math.floor((width + GAP) / (TILE + GAP)))
    local sell, total, y, usedTiles, usedHeads = {}, 0, 0, 0, 0
    for _, key in ipairs(ORDER) do
        local list = groups[key]
        if #list > 0 then
            table.sort(list, function(a, b) return (a.ah or a.de or a.vendor or 0) > (b.ah or b.de or b.vendor or 0) end)
            usedHeads = usedHeads + 1
            PaintHead(Head(usedHeads), key, list, y, width)
            y = y + HEAD_ROW + GAP
            for i, e in ipairs(list) do
                if Ticked(e) then
                    sell[#sell + 1] = e
                    total = total + (e.vendor or 0)
                end
                if not folded[key] then
                    usedTiles = usedTiles + 1
                    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                    PaintTile(Tile(usedTiles), e, col * (TILE + GAP), y + row * (TILE + GAP))
                end
            end
            if not folded[key] then y = y + math.ceil(#list / cols) * (TILE + GAP) end
            y = y + 8
        end
    end
    for i = usedTiles + 1, #tiles do tiles[i]:Hide() end
    for i = usedHeads + 1, #heads do heads[i]:Hide() end
    frame.list.content:SetHeight(math.max(1, y))
    frame.sellList = sell

    local busy = Seller.Busy()
    if busy then
        local done, n = Seller.Progress()
        frame.summary:SetText(L.selling:format(done, n))
    else
        frame.summary:SetText(#sell > 0 and L.selected:format(#sell, Money(total)) or L.nothing)
    end
    local can = #sell > 0 and not busy and Seller.AtMerchant()
    frame.sell:SetEnabled(can)
    frame.sell:SetAlpha(can and 1 or 0.45)
    local prices = Sendit.Service("auctionPrices")
    local at = prices and prices.At()
    frame.sub:SetText(at and L.freshAt:format(date("%d.%m. %H:%M", at)) or L.noPrices)
end

local pending = false
local function Soon()
    if pending or not frame or not frame:IsShown() then return end
    pending = true
    C_Timer.After(REPAINT, function()
        pending = false
        Window.Refresh()
    end)
end

local function Create()
    frame = CreateFrame("Frame", "SenditSellPanel", UIParent)
    Sendit.ownFrames[frame] = true
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    T.Fill(frame, "bg", "BACKGROUND"):SetAllPoints()
    local borders = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, edge in ipairs(borders) do edge:SetShown(not on) end
    end })
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("TOPLEFT", PAD, -15)
    icon:SetTexture(ns.ICON)
    frame.title = T.Text(frame, "title", "text")
    frame.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
    frame.sub = T.Text(frame, "small", "textMuted")
    frame.sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, -1)
    frame.sub:SetPoint("RIGHT", -44, 0)
    frame.sub:SetJustifyH("LEFT")
    frame.sub:SetWordWrap(false)
    W.Close(frame, Window.Hide):SetPoint("TOPRIGHT", -10, -14)
    local top = T.Fill(frame, "divider", "ARTWORK")
    top:SetHeight(1)
    top:SetPoint("TOPLEFT", 0, -HEADER)
    top:SetPoint("TOPRIGHT", 0, -HEADER)
    frame.list = W.ScrollArea(frame)
    frame.list:SetPoint("TOPLEFT", PAD, -(HEADER + 12))
    frame.list:SetPoint("BOTTOMRIGHT", -PAD, FOOTER + 8)
    local foot = T.Fill(frame, "footer", "BACKGROUND", 1)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(FOOTER)
    local edge = T.Fill(frame, "divider", "ARTWORK")
    edge:SetHeight(1)
    edge:SetPoint("BOTTOMLEFT", 0, FOOTER)
    edge:SetPoint("BOTTOMRIGHT", 0, FOOTER)
    frame.sell = W.Button(frame, L.sell, function() Seller.Sell(frame.sellList or {}) end, "primary")
    frame.sell:SetPoint("BOTTOMRIGHT", -PAD, (FOOTER - 28) / 2)
    frame.summary = T.Text(frame, "label", "text")
    frame.summary:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD, FOOTER / 2)
    frame.summary:SetPoint("RIGHT", frame.sell, "LEFT", -12, 0)
    frame.summary:SetJustifyH("LEFT")
    frame:HookScript("OnShow", function()
        frame.title:SetText(L.title)
        frame.sell:SetLabel(L.sell)
        Window.Refresh()
    end)
end

function Window.Open()
    if not Seller.AtMerchant() then return end
    if not frame then Create() end
    local merchant = _G["MerchantFrame"]
    frame:ClearAllPoints()
    if merchant and merchant:IsShown() then
        frame:SetPoint("TOPLEFT", merchant, "TOPRIGHT", 8, 0)
    else
        frame:SetPoint("CENTER")
    end
    frame:Show()
end

function Window.Hide() if frame then frame:Hide() end end
function Window.Shown() return frame ~= nil and frame:IsShown() end
function Window.Toggle() if Window.Shown() then Window.Hide() else Window.Open() end end

Seller.OnChange(Soon)

local events = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        ResetTicks()
        if ns.module.profile.autoOpen then C_Timer.After(0, Window.Open) end
    elseif event == "MERCHANT_CLOSED" then
        Window.Hide()
    else
        Soon()
    end
end)
