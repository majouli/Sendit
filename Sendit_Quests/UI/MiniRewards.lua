--[[
  MiniRewards: one line of reward value - item icons (fixed first, then pick-one with a corner
  mark), "+N" when they do not fit, XP badge, money (unknown or 0 left out).
  MiniRewards.Create(parent, iconSize) / Render(bar, width, data) -> shown / Items(data)
]]
local _, ns = ...
local T, S = Sendit.Theme, ns.Style
local Mini = {}
ns.MiniRewards = Mini
local GAP = 4

function Mini.Items(data)
    local list = {}
    for _, item in ipairs(data.items or {}) do list[#list + 1] = { itemId = item.itemId, amount = item.amount } end
    for _, choice in ipairs(data.choices or {}) do
        for _, item in ipairs(choice.items or { choice }) do
            list[#list + 1] = { itemId = item.itemId, amount = item.amount, choice = true }
        end
    end
    return list
end

function Mini.Create(parent, iconSize)
    local f = CreateFrame("Frame", nil, parent)
    f.iconSize = iconSize or S.size.icon
    f:SetHeight(f.iconSize)
    f.icons = {}
    f.more = CreateFrame("Frame", nil, f)
    f.more:SetHeight(f.iconSize)
    f.more:EnableMouse(true)
    f.more.text = T.Text(f.more, "small", "textDim")
    f.more.text:SetPoint("CENTER")
    f.more:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for _, row in ipairs(self.hidden or {}) do
            local name = ns.RewardIcon.Info(row.itemId)
            GameTooltip:AddLine((name or ("#" .. row.itemId)) .. (row.amount > 1 and (" x" .. row.amount) or "")
                .. (row.choice and (" (" .. ns.L.choiceShort .. ")") or ""), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    f.more:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.xp = CreateFrame("Frame", nil, f)
    f.xp:SetHeight(18)
    f.xp.bg = T.Fill(f.xp, "selected", "BACKGROUND")
    f.xp.bg:SetAllPoints()
    f.xp.text = T.Text(f.xp, "caption", "accent")
    f.xp.text:SetPoint("CENTER", 0, 0)
    f.money = T.Text(f, "small", "text")
    return f
end

function Mini.Render(f, width, data)
    local size = f.iconSize
    local xp, money = S.XP(data.xp), S.Money(data.money)
    f.xp.text:SetText(xp or "")
    f.money:SetText(money or "")
    local reserve = (xp and f.xp.text:GetStringWidth() + 16 + GAP or 0) + (money and f.money:GetStringWidth() + GAP or 0)
    local list = Mini.Items(data)
    local fit = math.max(0, math.floor((width - reserve + GAP) / (size + GAP)))
    local shown = #list <= fit and #list or math.max(0, fit - 1)
    local x = 0
    for i = 1, shown do
        local b = f.icons[i] or ns.RewardIcon.Create(f, size)
        f.icons[i] = b
        local row = list[i]
        b:Set(row.itemId, row.amount, row.choice)
        b:ClearAllPoints()
        b:SetPoint("LEFT", x, 0)
        x = x + size + GAP
    end
    for i = shown + 1, #f.icons do f.icons[i]:Hide() end
    local hidden = {}
    for i = shown + 1, #list do hidden[#hidden + 1] = list[i] end
    f.more.hidden = hidden
    f.more:SetShown(#hidden > 0)
    if #hidden > 0 then
        f.more.text:SetText("+" .. #hidden)
        f.more:SetWidth(size)
        f.more:ClearAllPoints()
        f.more:SetPoint("LEFT", x, 0)
        x = x + size + GAP
    end
    f.xp:SetShown(xp ~= nil)
    if xp then
        f.xp:SetWidth(f.xp.text:GetStringWidth() + 16)
        f.xp:ClearAllPoints()
        f.xp:SetPoint("LEFT", x, 0)
        x = x + f.xp:GetWidth() + GAP
    end
    f.money:SetShown(money ~= nil)
    if money then
        f.money:ClearAllPoints()
        f.money:SetPoint("LEFT", x, 0)
        x = x + f.money:GetStringWidth()
    end
    f:SetWidth(math.max(1, math.min(width, x)))
    f:SetShown(x > 0)
    return x > 0
end
