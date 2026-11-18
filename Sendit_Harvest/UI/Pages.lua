local _, ns = ...
local L = ns.L

local Sendit = Sendit
local O, W, T = Sendit.Options, Sendit.Widgets, Sendit.Theme

local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local NO_BOOK_FONT = { ruRU = true }
local MODEL_DISPLAY, MODEL_NPC = 3271, 906
local THANKS_H, MODEL_W = 118, 92
local TIER_SET = { 22506, 22507, 22504, 22511, 22509, 22510, 22505, 22508 }
local HUMAN, MALE = 1, 0

local PROFESSIONS = {
    { key = "disenchant", icon = "Interface\\Icons\\INV_Enchant_Disenchant" },
    { key = "skinning",   icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    { key = "mining",     icon = "Interface\\Icons\\Trade_Mining" },
    { key = "herbalism",  icon = "Interface\\Icons\\Trade_Herbalism" },
}
local DISPLAY = { { "names", "optNames" }, { "compact", "optCompact" }, { "chances", "optChances" }, { "value", "optValue" } }
local BEHAVIOR = { { "shiftOnly", "optShift" }, { "onlyKnown", "optKnown" } }

local texts = {}
local parts = {}

local function Dress(model)
    local ok = pcall(model.SetCustomRace, model, HUMAN, MALE)
    if not ok then ok = pcall(model.SetUnit, model, "player") end
    if not ok then return false end
    pcall(model.Undress, model)
    for _, id in ipairs(TIER_SET) do
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        pcall(model.TryOn, model, "item:" .. id)
    end
    return true
end

local function BuildModel(parent)
    local ok, model = pcall(CreateFrame, "DressUpModel", nil, parent)
    if ok and model and Dress(model) then
        local wanted = {}
        for _, id in ipairs(TIER_SET) do wanted[id] = true end
        pcall(model.RegisterEvent, model, "GET_ITEM_INFO_RECEIVED")
        model:SetScript("OnEvent", function(self, _, id) if wanted[id] then Dress(self) end end)
        model:SetScript("OnShow", function(self) Dress(self) end)
        model.dressed = true
        return model
    end
    model = CreateFrame("PlayerModel", nil, parent)
    if not pcall(model.SetDisplayInfo, model, MODEL_DISPLAY) then pcall(model.SetCreature, model, MODEL_NPC) end
    pcall(model.SetPortraitZoom, model, 0.35)
    return model
end

local function Learned(key)
    return not ns.Get("onlyKnown") or ns.Professions.Knows(key)
end

local function Switch(c, key)
    return W.Switch(c, function() return ns.Get(key) and true or false end, function(v) ns.Set(key, v) end)
end

local function Tx(key)
    return function() return L[key] end
end

local function Row(Lay, label, desc, control)
    local row = Lay:Row(label, desc, control)
    texts[#texts + 1] = { row = row }
    return row
end

local function CardTexts()
    local book = parts.bookFont and not NO_BOOK_FONT[ns.Language()]
    parts.thanksBook:SetShown(book)
    parts.thanksPlain:SetShown(not book)
    parts.thanksTitle = book and parts.thanksBook or parts.thanksPlain
    parts.thanksTitle:SetText(L.thanksTitle)
    parts.thanks:SetText(L.thanks)
    parts.about:SetText(L.aboutText)
    local version = C_AddOns.GetAddOnMetadata("Sendit_Harvest", "Version") or "?"
    parts.version:SetText(L.aboutVersion:format(version) .. "   " .. L.menuFooter)
end

local function AboutBlock(Lay)
    local block = CreateFrame("Frame")
    local heading = T.Text(block, "heading", "textMuted")
    heading:SetPoint("TOPLEFT")
    parts.heading = heading
    parts.about = T.Text(block, "note", "textDim")
    parts.about:SetPoint("TOPLEFT", 0, -22)
    parts.about:SetPoint("RIGHT", block, "RIGHT", 0, 0)
    parts.about:SetWordWrap(true)
    parts.about:SetJustifyH("LEFT")
    parts.about:SetText(L.aboutText)
    Lay:Place(block, 22 + math.max(parts.about:GetStringHeight() or 0, 42))

    local card = CreateFrame("Frame")
    T.Fill(card, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(card, "border")
    local stage = T.Fill(card, "bg", "ARTWORK")
    stage:SetPoint("TOPLEFT", 6, -6)
    stage:SetPoint("BOTTOMLEFT", 6, 6)
    stage:SetWidth(MODEL_W)
    local model = BuildModel(card)
    model:SetPoint("TOPLEFT", stage)
    model:SetPoint("BOTTOMRIGHT", stage)
    local facing = 0.6
    pcall(model.SetFacing, model, facing)
    model:SetScript("OnUpdate", function(self, elapsed)
        facing = (facing + elapsed * 0.4) % (2 * math.pi)
        pcall(self.SetFacing, self, facing)
    end)
    parts.thanksBook = T.Text(card, "title", "accent")
    parts.thanksBook:SetPoint("TOPLEFT", stage, "TOPRIGHT", 14, -14)
    parts.bookFont = pcall(parts.thanksBook.SetFont, parts.thanksBook, TITLE_FONT, 20, "")
    parts.thanksPlain = T.Text(card, "title", "accent")
    parts.thanksPlain:SetPoint("TOPLEFT", stage, "TOPRIGHT", 14, -16)
    parts.thanks = T.Text(card, "body", "text")
    parts.thanks:SetPoint("TOPLEFT", stage, "TOPRIGHT", 14, -48)
    parts.card, parts.model = card, model
    Lay:Place(card, THANKS_H)

    local foot = CreateFrame("Frame")
    parts.version = T.Text(foot, "small", "textMuted")
    parts.version:SetPoint("TOPLEFT")
    Lay:Place(foot, 16)
end

local function Build(Lay, c)
    Lay:Section(Tx("master"))
    Row(Lay, Tx("master"), function() return ns.Get("enabled") and L.on or L.off end, Switch(c, "enabled"))
    Lay:EndSection()

    Lay:Section(Tx("secProfessions"))
    for _, p in ipairs(PROFESSIONS) do
        local key = p.key
        Row(Lay, function() return ("|T%s:18:18:0:0:64:64:5:59:5:59|t  %s"):format(p.icon, L[key]) end,
            function()
                local status = not Learned(key) and L.notLearned or ns.Get(key) and L.cardOn or L.cardOff
                return L[key .. "What"] .. "  -  " .. status
            end, Switch(c, key))
    end
    Lay:EndSection()

    Lay:Section(Tx("dribTitle"))
    Row(Lay, function() return "|TInterface\\Icons\\INV_Enchant_Disenchant:18:18:0:0:64:64:5:59:5:59|t  " .. L.dribTitle end,
        function() return L.dribWhat .. "  -  /harvest dribbler" end,
        W.Button(c, L.dribOpen, function() ns.DribblerWindow.Open() end))
    Lay:EndSection()

    Lay:Section(Tx("secDisplay"))
    for _, d in ipairs(DISPLAY) do Row(Lay, Tx(d[2]), nil, Switch(c, d[1])) end
    Lay:EndSection()

    Lay:Section(Tx("secBehavior"))
    for _, b in ipairs(BEHAVIOR) do Row(Lay, Tx(b[2]), nil, Switch(c, b[1])) end
    Lay:EndSection()

    AboutBlock(Lay)
end

O:Register({
    key = "harvest",
    module = ns.module,
    title = "Harvest",
    subtitle = Tx("subtitle"),
    resetKeys = { "enabled", "disenchant", "skinning", "mining", "herbalism", "names", "compact", "chances",
                  "value", "shiftOnly", "onlyKnown" },
    build = function(frame)
        local layout = O.SettingsPage(Build)(frame)
        local refresh = layout.Refresh
        function layout:Refresh()
            parts.heading:SetText(L.secAbout:upper())
            CardTexts()
            refresh(self)
        end
        layout:Refresh()
        return layout
    end,
})

function ns.OpenSettings()
    local cur = O:Current()
    if cur and cur.module == ns.module then return O:Hide() end
    O:Show("harvest")
end

Sendit:AddQuickToggle({
    label = "Harvest",
    get = function() return ns.Get("enabled") end,
    set = function(v) ns.Set("enabled", v) end,
})

ns.Page = { texts = texts, parts = parts }
