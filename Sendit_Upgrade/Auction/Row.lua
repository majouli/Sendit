--[[
  Row: one ranked auction in the upgrade scan window - icon, name in its quality colour, gain, required
  level, auctions, price and the two-click buy button (Sendit_Upgrade/Auction/Buy.lua). Modified clicks
  act like on any item (shift: link in chat, ctrl: try on) with the full link from the client.
  Row.Create(parent) / Row.Paint(row, candidate, width); Row.HEIGHT; Row.Money(copper) -> coin text
]]
local _, ns = ...
local L, AL = ns.L, ns.AL
local T, W = Sendit.Theme, Sendit.Widgets
local Buy = ns.AuctionBuy
local Row = {}
ns.AuctionRow = Row

Row.HEIGHT = 50
local ICON, BUY_W, PRICE_W = 34, 96, 110

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
function Row.Money(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. COIN:format("Gold") end
    if s > 0 then parts[#parts + 1] = s .. COIN:format("Silver") end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COIN:format("Copper") end
    return table.concat(parts, " ")
end
local Money = Row.Money

local function QualityHex(q)
    local ok, _, _, _, hex = pcall(C_Item.GetItemQualityColor, q or 1)
    return ok and type(hex) == "string" and ("|c" .. hex) or ""
end

-- web links are bare item strings: the client gives the full link once it knows the item
local function FullLink(c)
    if c.link:find("|H", 1, true) then return c.link end
    local _, link = C_Item.GetItemInfo(c.link)
    return link
end

local function Gain(c)
    local s = ("+%.1f"):format(c.pct):gsub("%.", L.decimal)
    return s .. " % " .. (c.unit or "")
end

local LABELS = { searching = "searching", ready = "confirm", buying = "searching", bought = "bought", gone = "gone" }

function Row.Create(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(Row.HEIGHT)
    T.Fill(r, "panel", "BACKGROUND"):SetAllPoints()
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT", 10, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.name = T.Text(r, "body", "text")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -1)
    r.meta = T.Text(r, "small", "textMuted")
    r.meta:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 1)
    r.buy = W.Button(r, AL.buy, function(self)
        local c = self.c
        if not c then return end
        if c.buy == "ready" then Buy.Confirm(c) elseif not c.buy then Buy.Find(c) end
    end, "primary")
    r.buy:SetPoint("RIGHT", -10, 0)
    r.price = T.Text(r, "label", "text")
    r.price:SetPoint("RIGHT", r.buy, "LEFT", -10, 0)
    r.price:SetJustifyH("RIGHT")
    r.price:SetWidth(PRICE_W)
    r:SetScript("OnEnter", function(self)
        if not self.c then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(self.c.link)
        GameTooltip:AddLine(AL.buyHint, 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine(AL.clickHint, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    r:SetScript("OnClick", function(self)
        local link = self.c and FullLink(self.c)
        local handle = _G["HandleModifiedItemClick"]
        if link and handle and IsModifiedClick() then handle(link) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

function Row.Paint(r, c, width)
    r.c, r.buy.c = c, c
    r:SetWidth(width)
    r.icon:SetTexture(c.icon or 134400)
    local textW = width - ICON - BUY_W - PRICE_W - 52
    r.name:SetWidth(textW)
    r.meta:SetWidth(textW)
    local name = c.name or c.link:match("|h%[(.-)%]|h") or "?"
    r.name:SetText(QualityHex(c.quality) .. name .. "|r")
    local parts = { "|cff40ff40" .. Gain(c) .. "|r" }
    if c.gate then
        parts[#parts + 1] = AL.gate:format(c.gate)
    elseif c.reqLevel and c.reqLevel > 1 then
        parts[#parts + 1] = AL.req:format(c.reqLevel)
    end
    if c.count > 1 then parts[#parts + 1] = AL.auctions:format(c.count) end
    r.meta:SetText(table.concat(parts, "  ·  "))
    r.price:SetText(Money(c.price or c.buyout))
    r.buy:SetLabel(AL[LABELS[c.buy] or "buy"])
    r.buy:SetWidth(BUY_W)
    local can = Buy.AtHouse() and (c.buy == nil or (c.buy == "ready" and GetMoney() >= c.price))
    r.buy:SetEnabled(can)
    r.buy:SetAlpha(can and 1 or 0.45)
    r:Show()
end
