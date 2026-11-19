local _, ns = ...
local L = ns.L

local T, W = Sendit.Theme, Sendit.Widgets
local V, Session, Market = ns.DribblerValue, ns.DribblerSession, ns.DribblerMarket
local DE, Row, Summary, Mail = ns.DribblerDisenchant, ns.DribblerRow, ns.DribblerSummary, ns.DribblerMail

local Window = {}
ns.DribblerWindow = Window

local WIDTH, HEIGHT = 480, 640
local PAD, HEADER, TILE_H, TOOL_H, MATS_H, FOOTER = 16, 60, 56, 30, 58, 64
local MAT_SLOTS = 7
local MATS_X, MAT_ICON, MAT_GAP = 136, 22, 14
local ICON = "Interface\\Icons\\INV_Enchant_Disenchant"

local frame
local rows, offers = {}, {}
local hidePending = false

local function Money(c) return ns.Prices.Money(c) end
local function Store() return ns.db and ns.db.dribbler end

function Window.BracketIndex()
    local d = Store()
    local i = d and d.bracket
    if i and V.Bracket(i) then return i end
    return V.IndexOf(UnitLevel("player") or 25) or 3
end

function Window.KindIndex()
    local d = Store()
    return d and V.KINDS[d.kind or 1] and d.kind or 1
end

local function Search()
    Market.Query(Window.BracketIndex(), Window.KindIndex())
    Window.Refresh()
end

local function SetBracket(i)
    local d = Store()
    if d then d.bracket = i end
    Search()
end

local function SetKind(i)
    local d = Store()
    if d then d.kind = i end
    Search()
end

local function KindLabel(i)
    return ({ L.dribKindAll, L.dribKindArmor, L.dribKindWeapon })[i]
end

local function Tile(parent)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(TILE_H)
    T.Fill(t, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Border(t, "border")
    t.label = T.Text(t, "caption", "textMuted")
    t.label:SetPoint("TOPLEFT", 10, -9)
    t.value = T.Text(t, "heading", "text")
    t.value:SetPoint("BOTTOMLEFT", 10, 10)
    return t
end

local function MatSlot(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(52, 40)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(MAT_ICON, MAT_ICON)
    b.icon:SetPoint("TOP", 0, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.price = T.Text(b, "caption", "textDim")
    b.price:SetPoint("TOP", b.icon, "BOTTOM", 0, -4)
    b:SetScript("OnEnter", function(self)
        if not self.mat then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetItemByID(self.mat.item)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function Header()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("TOPLEFT", PAD, -15)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.title = T.Text(frame, "title", "text")
    frame.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    frame.sub = T.Text(frame, "small", "textMuted")
    frame.sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)
    frame.close = W.Close(frame, function() Window.Hide() end)
    frame.close:SetPoint("TOPRIGHT", -10, -12)
    local rule = T.Fill(frame, "divider", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)
end

local function IdleBody()
    local f = CreateFrame("Frame", nil, frame)
    f:SetPoint("TOPLEFT", PAD, -HEADER - PAD)
    f:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    f.intro = T.Text(f, "body", "textDim")
    f.intro:SetPoint("TOPLEFT")
    f.intro:SetWidth(WIDTH - 2 * PAD)
    f.intro:SetJustifyH("LEFT")
    f.intro:SetWordWrap(true)
    f.start = W.Button(f, L.dribStart, function() Window.Start() end, "primary")
    f.start:SetPoint("TOPLEFT", f.intro, "BOTTOMLEFT", 0, -16)
    f.lastTitle = T.Text(f, "label", "accent")
    f.lastTitle:SetPoint("TOPLEFT", f.start, "BOTTOMLEFT", 0, -28)
    f.card = CreateFrame("Frame", nil, f)
    f.card:SetPoint("TOPLEFT", f.lastTitle, "BOTTOMLEFT", 0, -12)
    f.card:SetSize(WIDTH - 2 * PAD, 10)
    frame.idle = f
end

local function ActiveBody()
    local f = CreateFrame("Frame", nil, frame)
    f:SetPoint("TOPLEFT", 0, -HEADER)
    f:SetPoint("BOTTOMRIGHT")
    local tileW = (WIDTH - 2 * PAD - 16) / 3
    f.tiles = {}
    for i = 1, 3 do
        local t = Tile(f)
        t:SetWidth(tileW)
        t:SetPoint("TOPLEFT", PAD + (i - 1) * (tileW + 8), -PAD)
        f.tiles[i] = t
    end
    local toolY = -PAD - TILE_H - 14
    f.chip = W.Chip(f, function(self)
        local options = {}
        for i = 1, #V.BRACKETS do options[i] = { i, L.dribBracket:format(V.Label(i)) } end
        W.ShowMenu(self, options, Window.BracketIndex(), SetBracket)
    end)
    f.chip:SetPoint("TOPRIGHT", -PAD, toolY)
    f.reload = W.Button(f, L.dribReload, Search)
    f.reload:SetPoint("RIGHT", f.chip, "LEFT", -8, 0)
    f.reload:SetHeight(26)
    f.deal = W.Button(f, L.dribDeal, function() Market.Buy(Market.BestDeal()) end, "primary")
    f.deal:SetPoint("TOPLEFT", PAD, toolY)
    f.deal:SetHeight(26)
    local matsY = toolY - TOOL_H - 10
    f.matsBg = T.Fill(f, "sidebar", "BACKGROUND")
    f.matsBg:SetPoint("TOPLEFT", PAD, matsY)
    f.matsBg:SetPoint("TOPRIGHT", -PAD, matsY)
    f.matsBg:SetHeight(MATS_H)
    f.matsTitle = T.Text(f, "caption", "textMuted")
    f.matsTitle:SetPoint("LEFT", f.matsBg, "LEFT", 10, 0)
    f.matsTitle:SetWidth(120)
    f.matsTitle:SetJustifyH("LEFT")
    f.matsTitle:SetWordWrap(true)
    f.mats = {}
    for i = 1, MAT_SLOTS do f.mats[i] = MatSlot(f) end
    local listY = matsY - MATS_H - 36
    f.kind = W.Chip(f, function(self)
        local options = {}
        for i = 1, #V.KINDS do options[i] = { i, KindLabel(i) } end
        W.ShowMenu(self, options, Window.KindIndex(), SetKind)
    end)
    f.kind:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -PAD, listY + 4)
    f.status = T.Text(f, "small", "textMuted")
    f.status:SetPoint("BOTTOMLEFT", f, "TOPLEFT", PAD + 2, listY + 6)
    f.status:SetJustifyH("LEFT")
    f.scroll = W.ScrollArea(f)
    f.scroll:SetPoint("TOPLEFT", PAD, listY)
    f.scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOTER)
    f.scroll:SetScript("OnVerticalScroll", function() Window.RenderRows() end)
    f.scroll:HookScript("OnMouseWheel", function() Window.RenderRows() end)
    f.empty = T.Text(f, "label", "textMuted")
    f.empty:SetPoint("TOPLEFT", f.scroll, "TOPLEFT", 4, -20)
    f.empty:SetWidth(WIDTH - 2 * PAD - 8)
    f.empty:SetWordWrap(true)
    f.empty:SetJustifyH("LEFT")
    local foot = T.Fill(f, "footer", "BACKGROUND")
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(FOOTER)
    f.de = DE.Create(f, "SenditHarvestDribblerDisenchant")
    f.de:SetPoint("BOTTOMLEFT", PAD, 14)
    f.de:SetSize(WIDTH - 2 * PAD - 138, 36)
    T.Fill(f.de, "accent", "BACKGROUND"):SetAllPoints()
    T.Fill(f.de, "selected", "HIGHLIGHT"):SetAllPoints()
    f.deIcon = f.de:CreateTexture(nil, "ARTWORK")
    f.deIcon:SetSize(24, 24)
    f.deIcon:SetPoint("LEFT", 8, 0)
    f.deIcon:SetTexture(ICON)
    f.deText = T.Text(f.de, "label", "onAccent")
    T.NoShadow(f.deText)
    f.deText:SetPoint("LEFT", f.deIcon, "RIGHT", 10, 0)
    f.deText:SetPoint("RIGHT", -8, 0)
    f.deText:SetJustifyH("LEFT")
    f.de:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.dribTitle, 1, 1, 1, 1)
        GameTooltip:AddLine(L.dribWheelHint, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    f.de:HookScript("OnLeave", function() GameTooltip:Hide() end)
    f.stop = W.Button(f, L.dribStop, function() Window.Stop() end)
    f.stop:SetPoint("BOTTOMRIGHT", -PAD, 14)
    f.stop:SetSize(128, 36)
    frame.active = f
end

function Window.RenderRows()
    if not frame or not frame.active:IsShown() then return end
    local scroll = frame.active.scroll
    local step = Row.HEIGHT + 4
    local first = math.floor((scroll:GetVerticalScroll() or 0) / step) + 1
    local last = math.min(#offers, first + math.ceil((scroll:GetHeight() or 0) / step) + 1)
    local used = 0
    for i = first, last do
        used = used + 1
        local r = rows[used] or Row.Create(scroll.content)
        rows[used] = r
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(i - 1) * step)
        Row.Paint(r, offers[i], WIDTH - 2 * PAD)
    end
    for i = used + 1, #rows do rows[i]:Hide() end
end

local function StatusText()
    if not Market.IsOpen() then return L.dribOpenAH end
    if Market.Browsing() then return L.dribSearching end
    if Market.Failed() then return L.dribFailed end
    return (#offers == 1 and L.dribOfferOne or L.dribOffers):format(#offers)
end

local function PaintMats(f, index)
    local mats = V.Mats(index, Window.KindIndex())
    f.matsTitle:SetText(L.dribMats)
    local x = MATS_X
    for i, slot in ipairs(f.mats) do
        local m = mats[i]
        slot.mat = m
        slot:SetShown(m ~= nil)
        if m then
            slot.icon:SetTexture(C_Item.GetItemIconByID(m.item) or 134400)
            slot.price:SetText(m.price and Money(m.price >= 100 and math.floor(m.price / 100 + 0.5) * 100 or m.price) or "?")
            local w = math.max(MAT_ICON, math.ceil(slot.price:GetStringWidth() or 0)) + MAT_GAP
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", f.matsBg, "TOPLEFT", x, -7)
            slot:SetWidth(w)
            x = x + w
        end
    end
end

local function PaintActive()
    local f = frame.active
    local s = Summary.Get()
    f.tiles[1].label:SetText(L.dribStartGold:upper())
    f.tiles[1].value:SetText(Money(s.startMoney))
    f.tiles[2].label:SetText(L.dribSpentShort:upper())
    f.tiles[2].value:SetText(Money(s.spent))
    f.tiles[3].label:SetText(L.dribProfit:upper())
    f.tiles[3].value:SetText((s.profit >= 0 and "+" or "-") .. Money(math.abs(s.profit)))
    T.Paint(f.tiles[3].value, s.profit >= 0 and "success" or "danger")
    local index = Window.BracketIndex()
    f.chip:SetLabel(L.dribBracket:format(V.Label(index)), true)
    f.kind:SetLabel(KindLabel(Window.KindIndex()), Window.KindIndex() ~= 1)
    f.reload:SetEnabled(Market.IsOpen())
    local deal = Market.BestDeal()
    f.deal:SetEnabled(deal ~= nil)
    f.deal:SetAlpha(deal and 1 or 0.4)
    offers = Market.IsOpen() and Market.Offers() or {}
    f.status:SetText(StatusText())
    PaintMats(f, index)
    f.scroll.content:SetHeight(math.max(1, #offers * (Row.HEIGHT + 4)))
    f.empty:SetShown(#offers == 0)
    f.empty:SetText(not Market.IsOpen() and L.dribOpenAHLong or (Market.Browsing() and "" or L.dribNone))
    Window.RenderRows()
    local ready, owned = DE.InBags(), Session.OwnedCount()
    local text = ready > 0 and L.dribDisenchant:format(ready) or L.dribNothing
    if Mail.Running() then
        text = text .. "  ·  " .. L.dribMailTaking
    elseif owned > ready then
        text = text .. "  ·  " .. L.dribInMail:format(owned - ready)
    end
    f.deText:SetText(text)
    f.de:SetAlpha(ready > 0 and 1 or 0.5)
end

local function PaintIdle()
    local f = frame.idle
    f.intro:SetText(L.dribIntro)
    f.start:SetLabel(L.dribStart)
    local s = Session.Current() and Summary.Get()
    f.lastTitle:SetShown(s ~= nil)
    f.card:SetShown(s ~= nil)
    if s then
        f.lastTitle:SetText(L.dribLast:upper())
        f.card:SetHeight(math.max(10, Summary.Paint(f.card, s, WIDTH - 2 * PAD)))
    end
end

function Window.Refresh()
    if not frame or not frame:IsShown() then return end
    local active = Session.Active()
    frame.title:SetText(L.dribTitle)
    frame.sub:SetText(active and L.dribRunning or L.dribSubtitle)
    if not InCombatLockdown() then
        frame.active:SetShown(active)
    end
    frame.idle:SetShown(not active)
    if active then PaintActive() else PaintIdle() end
    ns.DribblerTab.Refresh()
end

function Window.Start()
    if not Session.Start(GetMoney(), time()) then return end
    Window.Refresh()
    if Market.IsOpen() then Market.Query(Window.BracketIndex(), Window.KindIndex()) end
    Window.Refresh()
end

function Window.Stop()
    Session.Stop(GetMoney(), time())
    Window.Refresh()
end

local function Anchor()
    frame:ClearAllPoints()
    local ah, mail = _G["AuctionHouseFrame"], _G["MailFrame"]
    if ah and ah:IsShown() then
        frame:SetPoint("TOPLEFT", ah, "TOPRIGHT", 48, 0)
    elseif mail and mail:IsShown() then
        frame:SetPoint("TOPLEFT", mail, "TOPRIGHT", 12, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 260, 40)
    end
end

local function Create()
    frame = CreateFrame("Frame", "SenditHarvestDribbler", UIParent)
    Sendit.ownFrames[frame] = true
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local bg = T.Fill(frame, "bg", "BACKGROUND")
    bg:SetAllPoints()
    local _, _, _, alpha = T.Color("bg")
    T.Paint(bg, "bg", 1 / math.max(0.01, alpha))
    local borders = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, edge in ipairs(borders) do edge:SetShown(not on) end
    end })
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -40, 0)
    drag:SetHeight(HEADER)
    W.Movable(frame, drag)
    Header()
    IdleBody()
    ActiveBody()
    frame:SetScript("OnShow", function() Window.Refresh() end)
end

function Window.Open()
    if not frame then Create() end
    if InCombatLockdown() then return end
    if not frame:IsShown() then Anchor() end
    frame:Show()
    Window.Refresh()
    if Session.Active() and Market.IsOpen() and not Market.Bracket() then Market.Query(Window.BracketIndex(), Window.KindIndex()) end
end

function Window.Hide()
    if not frame then return end
    if InCombatLockdown() then
        hidePending = true
        return
    end
    frame:Hide()
end

function Window.Toggle()
    if frame and frame:IsShown() then Window.Hide() else Window.Open() end
end

function Window.Shown() return frame ~= nil and frame:IsShown() end

local pending = false
local function Soon()
    if pending or not Window.Shown() then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        Window.Refresh()
    end)
end

Market.OnChange(Soon)
Mail.OnChange(Soon)
DE.OnChange(Soon)
Sendit.OnSettingsChanged(function() if frame then Window.Refresh() end end)

local events = CreateFrame("Frame")
local mailOpened = false
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        C_Timer.After(0, function()
            ns.DribblerTab.Show()
            if Session.Active() then Window.Open() end
        end)
    elseif event == "MAIL_SHOW" then
        mailOpened = false
    elseif event == "MAIL_INBOX_UPDATE" then
        if not mailOpened and Session.Active() and Mail.Next() then
            mailOpened = true
            C_Timer.After(0, Window.Open)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if hidePending then
            hidePending = false
            Window.Hide()
        end
        Soon()
    else
        Soon()
    end
end)
