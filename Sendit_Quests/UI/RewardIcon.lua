--[[
  RewardIcon: one item as a square button - icon, quality frame, amount, tooltip; a corner mark for
  pick-one items; uncached items show a placeholder and are requested.
  RewardIcon.Create(parent, size) -> button;  button:Set(itemID, amount, choice);  RewardIcon.Info(itemID)
]]
local _, ns = ...
local T = Sendit.Theme
local Icon = {}
ns.RewardIcon = Icon
local requested = {}

local Read = ns.Read

function Icon.Info(itemID)
    local api = C_Item or {}
    local name, _, quality = Read(api.GetItemInfo, itemID)
    local icon = Read(api.GetItemIconByID, itemID)
    if not name and not requested[itemID] and api.RequestLoadItemDataByID then
        requested[itemID] = true
        pcall(api.RequestLoadItemDataByID, itemID)
    end
    return name, icon, quality
end

local function Quality(edges, quality)
    local colors = _G["ITEM_QUALITY_COLORS"]
    local c = quality and colors and colors[quality]
    for _, edge in ipairs(edges) do
        if c then edge:SetVertexColor(c.r, c.g, c.b, 0.9) else T.Paint(edge, "border") end
    end
end

function Icon.Create(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edges = T.Border(b, "border")
    b.count = T.Text(b, "caption", "text", "OVERLAY")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b.choice = T.Fill(b, "accent", "OVERLAY")
    b.choice:SetSize(5, 5)
    b.choice:SetPoint("TOPRIGHT", -1, -1)
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemID)
        if self.isChoice then GameTooltip:AddLine(ns.L.chooseReward, 1, 0.82, 0) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b:Set(itemID, amount, choice)
        self.itemID, self.isChoice = itemID, choice == true
        local _, icon, quality = Icon.Info(itemID)
        self.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.icon:SetVertexColor(1, 1, 1, icon and 1 or 0.35)
        Quality(self.edges, quality)
        self.count:SetText(amount and amount > 1 and tostring(amount) or "")
        self.choice:SetShown(self.isChoice)
        self:Show()
    end
    return b
end
