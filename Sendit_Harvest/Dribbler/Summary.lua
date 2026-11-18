local _, ns = ...
local L = ns.L

local T = Sendit.Theme
local V, Session = ns.DribblerValue, ns.DribblerSession

local Summary = {}
ns.DribblerSummary = Summary

local LINE = 20
local pool = {}

local function Money(c) return ns.Prices.Money(c) end

local function Signed(c)
    return (c >= 0 and "+" or "-") .. Money(math.abs(c))
end

function Summary.Get()
    return Session.Summary(GetMoney(), V.MatPrice, function(id) return (V.ForItem(id)) end, V.AH_CUT)
end

function Summary.Lines(s)
    local lines = {
        { L.dribStartGold, Money(s.startMoney) },
        { s.active and L.dribGoldNow or L.dribGoldEnd, Money(s.money) .. "  (" .. Signed(s.change) .. ")",
          s.change >= 0 and "success" or "danger" },
        { L.dribSpent:format(s.bought), Money(s.spent) },
        { L.dribDisenchanted, tostring(s.disenchanted) },
    }
    for _, m in ipairs(s.mats) do
        local name = ns.ItemName(m.id) or tostring(m.id)
        local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(m.id)
        local label = (icon and ("|T" .. icon .. ":14:14|t ") or "") .. m.count .. "x " .. (name or "")
        lines[#lines + 1] = { "   " .. label, m.value and Money(m.value) or L.dribNoPrice, nil, true }
    end
    if s.left > 0 then
        lines[#lines + 1] = { L.dribLeft:format(s.left), "~ " .. Money(s.leftValue) }
    end
    lines[#lines + 1] = { L.dribIncome, Money(s.income), "accent", false, true }
    lines[#lines + 1] = { L.dribProfit, Signed(s.profit), s.profit >= 0 and "success" or "danger", false, true }
    return lines
end

local function Line(parent, i)
    local l = pool[i]
    if l and l.parent == parent then return l end
    l = { parent = parent }
    l.label = T.Text(parent, "label", "textDim")
    l.label:SetJustifyH("LEFT")
    l.value = T.Text(parent, "label", "text")
    l.value:SetJustifyH("RIGHT")
    l.rule = T.Fill(parent, "divider", "ARTWORK")
    l.rule:SetHeight(1)
    pool[i] = l
    return l
end

function Summary.Paint(card, s, width)
    for _, l in ipairs(pool) do
        l.label:Hide()
        l.value:Hide()
        l.rule:Hide()
    end
    if not s then return 0 end
    local y = 0
    for i, row in ipairs(Summary.Lines(s)) do
        local l = Line(card, i)
        local strong = row[5]
        if strong then
            l.rule:ClearAllPoints()
            l.rule:SetPoint("TOPLEFT", 0, -y - 3)
            l.rule:SetWidth(width)
            l.rule:Show()
            y = y + 8
        end
        l.label:ClearAllPoints()
        l.label:SetPoint("TOPLEFT", 0, -y)
        l.label:SetWidth(width * 0.6)
        l.label:SetText(row[1])
        T.Paint(l.label, row[4] and "textMuted" or (strong and "text" or "textDim"))
        l.value:ClearAllPoints()
        l.value:SetPoint("TOPRIGHT", card, "TOPLEFT", width, -y)
        l.value:SetText(row[2])
        T.Paint(l.value, row[3] or "text")
        l.label:Show()
        l.value:Show()
        y = y + LINE
    end
    if s.unpriced then
        local l = Line(card, #Summary.Lines(s) + 1)
        l.label:ClearAllPoints()
        l.label:SetPoint("TOPLEFT", 0, -y - 4)
        l.label:SetWidth(width)
        l.label:SetText(L.dribUnpriced)
        T.Paint(l.label, "textMuted")
        l.label:Show()
        y = y + LINE + 4
    end
    return y
end
