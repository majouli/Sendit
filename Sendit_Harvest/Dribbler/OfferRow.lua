local _, ns = ...
local L = ns.L

local T, W = Sendit.Theme, Sendit.Widgets
local Market = ns.DribblerMarket
local Money = function(c) return ns.Prices.Money(c) end

local Row = {}
ns.DribblerRow = Row

Row.HEIGHT = 46
local ICON = 32
local BUY_W = 86
local PRICE_W = 84

local function QualityHex(q)
    local ok, _, _, _, hex = pcall(C_Item.GetItemQualityColor, q)
    if ok and type(hex) == "string" then return "|c" .. hex end
    return ""
end

function Row.Create(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(Row.HEIGHT)
    r.bg = T.Fill(r, "panel", "BACKGROUND")
    r.bg:SetAllPoints()
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    r.edge = T.Fill(r, "success", "ARTWORK")
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(3)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT", 10, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.name = T.Text(r, "body", "text")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -1)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.meta = T.Text(r, "small", "textMuted")
    r.meta:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 1)
    r.meta:SetJustifyH("LEFT")
    r.meta:SetWordWrap(false)
    r.buy = W.Button(r, L.dribBuy, function(self)
        if self.offer then Market.Buy(self.offer) end
    end, "primary")
    r.buy:SetSize(BUY_W, 26)
    r.buy:SetPoint("RIGHT", -10, 0)
    r.price = T.Text(r, "label", "text")
    r.price:SetPoint("TOPRIGHT", r.buy, "TOPLEFT", -12, 4)
    r.price:SetJustifyH("RIGHT")
    r.profit = T.Text(r, "small", "success")
    r.profit:SetPoint("BOTTOMRIGHT", r.buy, "BOTTOMLEFT", -12, -4)
    r.profit:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        if not self.offer then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.offer.link then
            GameTooltip:SetHyperlink(self.offer.link)
        elseif self.offer.itemID then
            GameTooltip:SetItemByID(self.offer.itemID)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function BuyLabel(o)
    if o.buying then return L.dribBuying end
    if o.searching or (not o.searched and not o.auctionID) then return "..." end
    if o.gone then return L.dribGone end
    return L.dribBuy
end

function Row.Paint(r, o, width)
    r.offer, r.buy.offer = o, o
    r:SetWidth(width)
    r.icon:SetTexture(o.icon or 134400)
    local textW = width - ICON - 30 - BUY_W - PRICE_W - 24
    r.name:SetWidth(textW)
    r.meta:SetWidth(textW)
    r.name:SetText(QualityHex(o.quality) .. (o.name or "?") .. "|r")
    local parts = { L.dribItemLevel:format(o.itemLevel) }
    if o.reqLevel and o.reqLevel > 0 then parts[#parts + 1] = L.dribReq:format(o.reqLevel) end
    if o.auctions and o.auctions > 1 then parts[#parts + 1] = L.dribAuctions:format(o.auctions) end
    r.meta:SetText(table.concat(parts, "  ·  "))
    r.price:SetText(o.buyout and Money(o.buyout) or L.dribFrom:format(Money(o.minPrice or 0)))
    local profit = Market.Profit(o)
    r.edge:SetShown(profit ~= nil and profit > 0)
    if profit then
        local sign = profit >= 0 and "+" or "-"
        r.profit:SetText((o.priced and "" or "~ ") .. sign .. Money(math.abs(profit)))
        T.Paint(r.profit, profit >= 0 and "success" or "danger")
    else
        r.profit:SetText("")
    end
    r.buy:SetLabel(BuyLabel(o))
    r.buy:SetWidth(BUY_W)
    local can = Market.CanBuy(o)
    r.buy:SetEnabled(can)
    r.buy:SetAlpha(can and 1 or 0.4)
    r:Show()
end
