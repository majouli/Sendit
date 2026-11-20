--[[
  LootIcon: one boss drop - icon in a quality frame, drop chance below, item tooltip; counts glow
  gold and breathe slowly while the boost runs. Uncached items show a placeholder and are requested.
  LootIcon.Create(parent) -> button;  button:Set(itemID, chance);  LootIcon.WIDTH / HEIGHT
]]
local _, ns = ...
local T, S = Sendit.Theme, ns.Style
local Icon = {}
ns.LootIcon = Icon
Icon.WIDTH, Icon.HEIGHT = S.size.icon, S.size.icon + S.size.chance + 2
local PULSE = 0.9  -- seconds per half breath of an upgrade's glow
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
    if v <= 0 then return "?" end
    if v >= 10 then return tostring(math.floor(v + 0.5)) .. "%" end
    return S.Pct(v) .. "%"
end

function Icon.Create(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(Icon.WIDTH, Icon.HEIGHT)
    -- the glow sits on its own frame: its frame alpha pulses (a painted texture keeps its alpha)
    b.glow = CreateFrame("Frame", nil, b)
    b.glow:SetSize(S.size.icon + 6, S.size.icon + 6)
    b.glow:SetPoint("TOP", 0, 3)
    T.Fill(b.glow, "accent", "BACKGROUND", nil, 0.55):SetAllPoints()
    b.pulse = b.glow:CreateAnimationGroup()
    b.pulse:SetLooping("BOUNCE")
    local fade = b.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.25)
    fade:SetDuration(PULSE)
    fade:SetSmoothing("IN_OUT")
    local box = CreateFrame("Frame", nil, b)
    box:SetSize(S.size.icon, S.size.icon)
    box:SetPoint("TOP")
    box:SetFrameLevel(b.glow:GetFrameLevel() + 1)
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
        if upgrade and not self.pulse:IsPlaying() then self.pulse:Play()
        elseif not upgrade then self.pulse:Stop() end
        self.chance:SetText(Chance(chance))
        T.Paint(self.chance, upgrade and "accent" or "textMuted")
        self:Show()
    end
    return b
end
