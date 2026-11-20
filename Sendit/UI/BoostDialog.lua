--[[
  BoostDialog: a module's gear boost settings under its chip - threshold, an optional switch, preview
  levels, slots, the spec, Boost / End. Enter = Boost; Escape or a click elsewhere closes it (the click
  is not swallowed: GLOBAL_MOUSE_DOWN, no screen-wide catcher). One panel, filled per call.
  Sendit.BoostDialog.Toggle(anchor, cfg) / Hide() / IsShown() / Panel()
    cfg = { L, boost, ahead = { { n, text }, ... }, switch = { get, set, text } | nil,
            onChange(what) ("ahead" | "slots" | "switch"), onStart(), onEnd() }
    L: boost, boostFor, boostNeedsUpgrade, boostMinLabel, boostMinHint, boostAhead, boostSlots, slotsAll,
       slotsNone, boostGo, boostAgain, boostEnd, boostCancel, decimal, slotWeapon, slotOffhand, slotRanged
    boost: Min / SetMin, Ahead / SetAhead, Active, Slot(key) / SetSlot(key, on)
]]
local _, ns = ...
local T, W, Slots = ns.Theme, ns.Widgets, ns.GearSlots
local Dialog = {}
ns.BoostDialog = Dialog
local panel, anchorFrame, cfg
local WIDTH = 320
local FIELD = 56

function Dialog.Hide() if panel then panel:Hide() end end
function Dialog.IsShown() return panel ~= nil and panel:IsShown() end
function Dialog.Panel() return panel end

local function Changed(what) if cfg and cfg.onChange then cfg.onChange(what) end end

local function Start()
    local v = tonumber(((panel.min:GetText() or ""):gsub(",", ".")))
    if v then cfg.boost.SetMin(v) end
    Dialog.Hide()
    cfg.onStart()
end

local function End()
    Dialog.Hide()
    if cfg.boost.Active() then cfg.onEnd() end
end

local function Build()
    panel = CreateFrame("Frame", "SenditBoostDialog", UIParent)
    panel:Hide()
    panel:SetWidth(WIDTH)
    panel:EnableMouse(true)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetClampedToScreen(true)
    ns.ownFrames[panel] = true
    tinsert(UISpecialFrames, "SenditBoostDialog")
    panel:RegisterEvent("GLOBAL_MOUSE_DOWN")
    panel:SetScript("OnEvent", function(self)
        if not self:IsShown() or self:IsMouseOver() then return end
        if anchorFrame and anchorFrame:IsMouseOver() then return end  -- the chip toggles it itself
        Dialog.Hide()
    end)
    T.Fill(panel, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(panel, "border")
    local edge = T.Fill(panel, "accent", "ARTWORK")
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("TOPRIGHT")
    edge:SetHeight(2)
    panel.title = T.Text(panel, "heading", "accent")
    panel.title:SetPoint("TOPLEFT", 16, -14)
    panel.spec = T.Text(panel, "small", "textMuted")
    panel.spec:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -4)
    panel.spec:SetWidth(WIDTH - 32)
    panel.spec:SetWordWrap(true)
    panel.minLabel = T.Text(panel, "label", "text")
    panel.minLabel:SetWidth(WIDTH - 32 - FIELD - 10)
    panel.minLabel:SetJustifyH("LEFT")
    panel.minLabel:SetWordWrap(true)
    panel.min = W.Search(panel, "", function() end)
    panel.min:SetSize(FIELD, 26)
    panel.min:SetMaxLetters(4)  -- "0,5" / "1.5"
    panel.min:SetTextInsets(8, 22, 0, 0)
    local pct = T.Text(panel.min, "label", "textMuted")
    pct:SetPoint("RIGHT", -8, 0)
    pct:SetText("%")
    panel.minHint = T.Text(panel, "small", "textMuted")
    panel.minHint:SetWidth(WIDTH - 32)
    panel.minHint:SetWordWrap(true)
    panel.switch = W.Switch(panel, function() return cfg.switch and cfg.switch.get() end,
        function(on) if cfg.switch then cfg.switch.set(on) Changed("switch") end end)
    panel.switchLabel = T.Text(panel, "label", "text")
    panel.switchLabel:SetWidth(WIDTH - 32 - 48)
    panel.switchLabel:SetWordWrap(true)
    panel.aheadLabel = T.Text(panel, "label", "text")
    panel.aheadLabel:SetWidth(WIDTH - 32)
    panel.aheadLabel:SetJustifyH("LEFT")
    panel.aheadLabel:SetWordWrap(true)
    panel.slotTitle = T.Text(panel, "label", "text")
    panel.slotChecks = {}
    for i, g in ipairs(Slots.GROUPS) do
        local check = W.Check(panel, function(self, on)
            cfg.boost.SetSlot(g.key, on)
            self:Set(on)
            Changed("slots")
        end)
        check.label = T.Text(panel, "small", "textDim")
        check.label:SetPoint("LEFT", check, "RIGHT", 6, 0)
        check.group = g
        panel.slotChecks[i] = check
    end
    local function All(on)
        for _, check in ipairs(panel.slotChecks) do
            cfg.boost.SetSlot(check.group.key, on)
            check:Set(on)
        end
        Changed("slots")
    end
    panel.allSlots = W.Button(panel, "", function() All(true) end)
    panel.noSlots = W.Button(panel, "", function() All(false) end)
    panel.go = W.Button(panel, "", Start, "primary")
    panel.stop = W.Button(panel, "", End)
    panel.min:SetScript("OnEnterPressed", function(self) self:ClearFocus() Start() end)
    panel.min:SetScript("OnEscapePressed", function() Dialog.Hide() end)
end

-- the preview levels: a segmented control per option set (Quests and Dungeons offer different ones)
local aheadControls = {}
local function Ahead(options)
    local values = {}
    for _, o in ipairs(options) do values[#values + 1] = tostring(o[1]) end
    local key = table.concat(values, ",")
    if not aheadControls[key] then
        local c = W.Segmented(panel, options, function() return cfg.boost.Ahead() end,
            function(n) cfg.boost.SetAhead(n) Changed("ahead") end)
        c:SetWidth(WIDTH - 32)
        aheadControls[key] = c
    end
    for k, c in pairs(aheadControls) do c:SetShown(k == key) end
    return aheadControls[key]
end

local function Layout(ahead)
    local y = 14 + panel.title:GetStringHeight() + 4 + panel.spec:GetStringHeight() + 16
    panel.minLabel:ClearAllPoints()
    panel.minLabel:SetPoint("TOPLEFT", 16, -(y + 4))
    panel.min:ClearAllPoints()
    panel.min:SetPoint("TOPRIGHT", -16, -y)
    y = y + math.max(26, panel.minLabel:GetStringHeight() + 8) + 6
    panel.minHint:ClearAllPoints()
    panel.minHint:SetPoint("TOPLEFT", 16, -y)
    y = y + panel.minHint:GetStringHeight() + 14
    panel.switch:SetShown(cfg.switch ~= nil)
    panel.switchLabel:SetShown(cfg.switch ~= nil)
    if cfg.switch then
        panel.switch:ClearAllPoints()
        panel.switch:SetPoint("TOPRIGHT", -16, -y)
        panel.switchLabel:ClearAllPoints()
        panel.switchLabel:SetPoint("TOPLEFT", 16, -(y + 3))
        y = y + math.max(20, panel.switchLabel:GetStringHeight()) + 16
    end
    panel.aheadLabel:ClearAllPoints()
    panel.aheadLabel:SetPoint("TOPLEFT", 16, -y)
    y = y + panel.aheadLabel:GetStringHeight() + 6
    ahead:ClearAllPoints()
    ahead:SetPoint("TOPLEFT", 16, -y)
    y = y + 28 + 16
    panel.slotTitle:ClearAllPoints()
    panel.slotTitle:SetPoint("TOPLEFT", 16, -y)
    panel.noSlots:ClearAllPoints()
    panel.noSlots:SetPoint("TOPRIGHT", -16, -(y - 6))
    panel.allSlots:ClearAllPoints()
    panel.allSlots:SetPoint("RIGHT", panel.noSlots, "LEFT", -6, 0)
    y = y + 28
    local cols, colW = 3, (WIDTH - 32) / 3
    for i, check in ipairs(panel.slotChecks) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", 16 + col * colW, -(y + row * 24))
        check.label:SetWidth(colW - 26)
    end
    y = y + math.ceil(#panel.slotChecks / cols) * 24 + 14
    panel.go:ClearAllPoints()
    panel.go:SetPoint("TOPRIGHT", -16, -y)
    panel.stop:ClearAllPoints()
    panel.stop:SetPoint("RIGHT", panel.go, "LEFT", -8, 0)
    panel:SetHeight(y + 28 + 16)
end

function Dialog.Toggle(anchor, config)
    if Dialog.IsShown() and cfg == config then Dialog.Hide() return end
    cfg = config
    if not panel then Build() end
    local L, boost = cfg.L, cfg.boost
    local svc = ns.Service("upgrade")
    local active = boost.Active()
    panel.title:SetText(L.boost)
    panel.spec:SetText(svc and L.boostFor:format(svc.Spec() or "?") or L.boostNeedsUpgrade)
    panel.minLabel:SetText(L.boostMinLabel)
    panel.min:SetText((tostring(boost.Min()):gsub("%.", L.decimal)))
    panel.minHint:SetText(L.boostMinHint)
    if cfg.switch then
        panel.switchLabel:SetText(cfg.switch.text)
        panel.switch:Refresh()
    end
    panel.aheadLabel:SetText(L.boostAhead)
    local ahead = Ahead(cfg.ahead)
    if ahead.Refresh then ahead:Refresh() end
    panel.slotTitle:SetText(L.boostSlots)
    for _, check in ipairs(panel.slotChecks) do
        check.label:SetText(Slots.Label(check.group, L))
        check:Set(boost.Slot(check.group.key))
    end
    panel.allSlots:SetLabel(L.slotsAll)
    panel.noSlots:SetLabel(L.slotsNone)
    panel.go:SetLabel(active and L.boostAgain or L.boostGo)
    panel.go:SetEnabled(svc ~= nil)
    panel.stop:SetLabel(active and L.boostEnd or L.boostCancel)
    Layout(ahead)
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6)
    anchorFrame = anchor
    panel:Show()
    T.FadeIn(panel, 0.12, 4)
    panel.min:SetFocus()
    panel.min:HighlightText()
end
