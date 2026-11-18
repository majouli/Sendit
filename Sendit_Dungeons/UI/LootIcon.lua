--[[
  LootIcon: one boss drop - the client's icon in a quality coloured frame, its
  drop chance below, the full item tooltip on hover. While the gear boost runs,
  an item that counts glows gold and its tooltip names the gain (the same
  number as Upgrade's item tooltip). Items the client has not cached yet show
  a dim placeholder and are requested; GET_ITEM_INFO_RECEIVED repaints the
  window (UI/Window.lua).

  LootIcon.Create(parent) -> button;  button:Set(itemID, chance)
  LootIcon.WIDTH / HEIGHT   the space one icon takes (icon + chance line)
]]
local _, ns = ...
local T, S = Sendit.Theme, ns.Style
local Icon = {}
ns.LootIcon = Icon
Icon.WIDTH, Icon.HEIGHT = S.size.icon, S.size.icon + S.size.chance + 2
local requested = {}

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue and (issecretvalue(a) or issecretvalue(b) or issecretvalue(c)) then return nil end
    return a, b, c
end

local function Info(itemID)
    local api = C_Item or {}
    local name, _, quality = Read(api.GetItemInfo, itemID)
    local icon = Read(api.GetItemIconByID, itemID)
    if not name and not requested[itemID] and api.RequestLoadItemDataByID then
        requested[itemID] = true
        pcall(api.RequestLoadItemDataByID, itemID)
    end
    return name, icon, quality
end
Icon.Info = Info

local function Chance(v)
    if v <= 0 then return "?" end  -- collected by hand without a chance
    if v >= 10 then return tostring(math.floor(v + 0.5)) .. "%" end
    return S.Pct(v) .. "%"
end

function Icon.Create(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(Icon.WIDTH, Icon.HEIGHT)
    local box = CreateFrame("Frame", nil, b)
    box:SetSize(S.size.icon, S.size.icon)
    box:SetPoint("TOP")
    b.glow = T.Fill(box, "accent", "BACKGROUND", nil, 0.35)
    b.glow:SetPoint("TOPLEFT", -3, 3)
    b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    b.icon = box:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edges = T.Border(box, "border")
    T.Fill(box, "hover", "HIGHLIGHT"):SetAllPoints()
    b.chance = T.Text(b, "caption", "textMuted")
    b.chance:SetPoint("TOP", box, "BOTTOM", 0, -2)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemID)
        if self.dropChance > 0 then GameTooltip:AddLine(ns.L.chance:format(S.Pct(self.dropChance)), 0.7, 0.7, 0.7) end
        local r = ns.Boost.Item(self.itemID)
        if r then
            local cr, cg, cb = S.Hex("accent")
            if r.gate then GameTooltip:AddLine(ns.L.fromLevel:format(r.gate), 0.7, 0.7, 0.7) end
            GameTooltip:AddLine(S.Upgrade(r), cr, cg, cb)
            GameTooltip:AddLine(ns.L.detailVs:format(r.label or "?"), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b:Set(itemID, chance)
        self.itemID, self.dropChance = itemID, chance
        local _, icon, quality = Info(itemID)
        self.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.icon:SetVertexColor(1, 1, 1, icon and 1 or 0.35)
        local colors = _G["ITEM_QUALITY_COLORS"]
        local c = quality and colors and colors[quality]
        for _, edge in ipairs(self.edges) do
            if c then edge:SetVertexColor(c.r, c.g, c.b, 0.9) else T.Paint(edge, "border") end
        end
        local upgrade = ns.Boost.Item(itemID) ~= nil
        self.glow:SetShown(upgrade)
        self.chance:SetText(Chance(chance))
        T.Paint(self.chance, upgrade and "accent" or "textMuted")
        self:Show()
    end
    return b
end
