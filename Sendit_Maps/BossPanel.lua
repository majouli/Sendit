--[[
  BossPanel: a panel flush beside the map window (right, or left when the screen ends) - the boss whose pin was clicked - portrait, name, its loot with drop chance and
  what it gains you (Sendit Upgrade, when on), and a button to the dungeon browser (opens next to the map).
  BossPanel.Create(window) -> panel;  panel:ShowBoss(npc) / panel:Close().  It moves and hides with the window.
]]
local _, ns = ...
local T, W = Sendit.Theme, Sendit.Widgets
local L = ns.L
local BossPanel = {}
ns.BossPanel = BossPanel

local WIDTH, PAD, ICON, GAP, PER_ROW = 290, 14, 40, 10, 5
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local ratings = Sendit.ItemRatings and Sendit.ItemRatings.New()

local function Quality(itemID)
    local api = C_Item or {}
    local ok, _, _, q = pcall(api.GetItemInfo, itemID)
    if not ok or type(q) ~= "number" then return nil end
    local ok2, r, g, b = pcall(api.GetItemQualityColor, q)
    if ok2 and type(r) == "number" then return r, g, b end
    return nil
end

local function Cell(parent)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(ICON, ICON)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 1, -1)
    cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.edge = T.Border(cell, "border")
    cell.chance = T.Text(cell, "small", "textMuted")
    cell.chance:SetPoint("TOP", cell, "BOTTOM", 0, -2)
    cell.gain = T.Text(cell, "small", "success")
    cell.gain:SetPoint("TOPRIGHT", 2, 6)
    cell:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cell:SetScript("OnClick", function(self)
        if not IsModifiedClick("CHATLINK") then return end
        local ok, _, link = pcall((C_Item or {}).GetItemInfo, self.itemID)
        local insert = _G["ChatEdit_InsertLink"]
        if ok and link and insert then insert(link) end
    end)
    return cell
end

local Methods = {}

function Methods:PaintLoot()
    for _, cell in ipairs(self.cells) do
        if cell:IsShown() then
            local r, g, b = Quality(cell.itemID)
            for _, edge in ipairs(cell.edge) do
                if r then
                    T.Own(edge)
                    edge:SetVertexColor(r, g, b, 1)
                else
                    T.Paint(edge, "border")
                end
            end
            local rating = ratings and ratings.Get(cell.itemID)
            local pct = rating and rating.primary and rating.primary.pct
            cell.gain:SetText(type(pct) == "number" and pct > 0 and ("+%.1f%%"):format(pct) or "")
        end
    end
end

function Methods:ShowBoss(npc)
    local svc = Sendit.Service("dungeons")
    local info = svc and svc.Boss and svc.Boss(npc)
    if not info then return self:Hide() end
    self.info = info
    local fn = _G["SetPortraitTextureFromCreatureDisplayID"]
    if not (fn and (info.display or 0) > 0 and pcall(fn, self.face, info.display)) then self.face:SetTexture(SKULL) end
    self.name:SetText(info.name)
    self.kind:SetText(L.boss)
    local ids = {}
    for i, drop in ipairs(info.loot or {}) do
        local cell = self.cells[i] or Cell(self.body)
        self.cells[i] = cell
        cell.itemID = drop[1]
        ids[#ids + 1] = drop[1]
        local api = C_Item or {}
        local icon = api.GetItemIconByID and api.GetItemIconByID(drop[1])
        cell.icon:SetTexture(icon or 134400)
        cell.chance:SetText((drop[2] or 0) > 0 and (math.floor(drop[2] + 0.5) .. "%") or "")
        cell:ClearAllPoints()
        local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
        cell:SetPoint("TOPLEFT", col * (ICON + GAP), -row * (ICON + 26))
        cell:Show()
    end
    for i = #(info.loot or {}) + 1, #self.cells do self.cells[i]:Hide() end
    self.empty:SetShown(#(info.loot or {}) == 0)
    if ratings and #ids > 0 then ratings.Start(ids, function() self:PaintLoot() end, function() self:PaintLoot() end) end
    self:PaintLoot()
    if not self:IsShown() then
        self:Place()
        self:Show()
    end
end

function Methods:Close()
    if ratings then ratings.Stop() end
    if self:IsShown() then
        self:Hide()
    end
end

-- flush on the window's right edge; on its left when the screen has no room there
function Methods:Place()
    local window = self.window
    self:ClearAllPoints()
    local right = window:GetRight()
    if right and right + WIDTH > UIParent:GetRight() then
        self:SetPoint("TOPRIGHT", window, "TOPLEFT", 1, 0)
        self:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 1, 0)
    else
        self:SetPoint("TOPLEFT", window, "TOPRIGHT", -1, 0)
        self:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", -1, 0)
    end
end

function BossPanel.Create(window)
    local panel = CreateFrame("Frame", nil, window)
    for name, fn in pairs(Methods) do panel[name] = fn end
    panel.cells, panel.window = {}, window
    panel:SetWidth(WIDTH)
    panel:Hide()
    T.Fill(panel, "bg", "BACKGROUND"):SetAllPoints()
    T.Border(panel, "border")
    W.Close(panel, function() panel:Close() end):SetPoint("TOPRIGHT", -8, -8)

    local ring = T.Circle(panel, "accent", 64, "BACKGROUND", 1)
    ring:SetPoint("TOPLEFT", PAD, -PAD)
    panel.face = panel:CreateTexture(nil, "ARTWORK")
    panel.face:SetSize(60, 60)
    panel.face:SetPoint("CENTER", ring)
    panel.kind = T.Text(panel, "small", "textMuted")
    panel.kind:SetPoint("TOPLEFT", ring, "TOPRIGHT", 12, -10)
    panel.name = T.Text(panel, "heading", "text")
    panel.name:SetPoint("TOPLEFT", panel.kind, "BOTTOMLEFT", 0, -4)
    panel.name:SetPoint("RIGHT", -PAD, 0)
    panel.name:SetJustifyH("LEFT")

    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetPoint("TOPLEFT", PAD, -(PAD + 64 + 20))
    panel.body:SetPoint("RIGHT", -PAD, 0)
    panel.body:SetHeight(1)
    panel.empty = T.Text(panel.body, "note", "textMuted")
    panel.empty:SetPoint("TOPLEFT")
    panel.empty:SetText(L.noLoot)

    local open = W.Button(panel, Sendit.Locale.Text(L, "inDungeons"), function()
        local svc = Sendit.Service("dungeons")
        if svc and svc.Open and panel.info then svc.Open(panel.info.id, panel.info.boss) end
    end)
    open:SetPoint("BOTTOMLEFT", PAD, PAD)
    open:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    local events = CreateFrame("Frame", nil, panel)
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", function() if panel:IsShown() then panel:PaintLoot() end end)
    return panel
end
