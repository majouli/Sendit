--[[
  BoostDialog: what the gear boost needs, asked once - a small panel under
  the boost chip. "At least [5] % stronger", "also quests of a chain that are
  still locked", the preview (quests up to 0 / +1 / +2 / +3 / +5 levels above
  you), which slots count (check boxes, all / none), for which spec
  Sendit Upgrade rates, and the buttons:
  Boost (start; while it runs: rate again) and End. Enter in the field =
  Boost, Escape / a click outside closes it without starting anything. The
  click outside is not swallowed: no screen-wide catcher - the panel listens
  to GLOBAL_MOUSE_DOWN, so the click still reaches what it was meant for.
  Labels wrap within the panel: nothing runs into the field or past the edge.

  BoostDialog.Toggle(anchor, onStart, onEnd) / Hide() / IsShown()
]]
local _, ns = ...
local T, W, L = Sendit.Theme, Sendit.Widgets, ns.L
local Dialog = {}
ns.BoostDialog = Dialog
local panel, anchorFrame
local WIDTH = 320
local FIELD = 56

function Dialog.Hide() if panel then panel:Hide() end end
function Dialog.IsShown() return panel ~= nil and panel:IsShown() end

local function Build()
    panel = CreateFrame("Frame", "SenditQuestsBoostDialog", UIParent)
    panel:Hide()
    panel:SetWidth(WIDTH)
    panel:EnableMouse(true)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetClampedToScreen(true)
    Sendit.ownFrames[panel] = true
    tinsert(UISpecialFrames, "SenditQuestsBoostDialog")
    -- a click anywhere else closes it - and still reaches whatever was clicked
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
    panel.min:SetMaxLetters(4)  -- "0,5" / "1.5": decimals, comma or point
    panel.min:SetTextInsets(8, 22, 0, 0)
    local pct = T.Text(panel.min, "label", "textMuted")
    pct:SetPoint("RIGHT", -8, 0)
    pct:SetText("%")
    panel.minHint = T.Text(panel, "small", "textMuted")
    panel.minHint:SetWidth(WIDTH - 32)
    panel.minHint:SetWordWrap(true)
    panel.locked = W.Switch(panel, function() return ns.Boost.Locked() end, function(on) ns.Boost.SetLocked(on) end)
    panel.lockedLabel = T.Text(panel, "label", "text")
    panel.lockedLabel:SetWidth(WIDTH - 32 - 48)
    panel.lockedLabel:SetWordWrap(true)
    panel.aheadLabel = T.Text(panel, "label", "text")
    panel.aheadLabel:SetWidth(WIDTH - 32)
    panel.aheadLabel:SetJustifyH("LEFT")
    panel.aheadLabel:SetWordWrap(true)
    panel.ahead = W.Segmented(panel, { { 0, "0" }, { 1, "+1" }, { 2, "+2" }, { 3, "+3" }, { 5, "+5" } },
        function() return ns.Boost.Ahead() end,
        function(n)
            ns.Boost.SetAhead(n)
            if ns.Boost.Active() then ns.Boost.Start() end  -- other quests count now: rate again
            if ns.Window then ns.Window:BoostChanged() end
        end)
    panel.ahead:SetWidth(WIDTH - 32)
    -- slots: a grid of small check boxes with the client's slot names
    panel.slotTitle = T.Text(panel, "label", "text")
    panel.slotChecks = {}
    for i, g in ipairs(ns.Boost.SLOTS) do
        local check = W.Check(panel, function(self, on)
            ns.Boost.SetSlot(g.key, on)
            self:Set(on)
            if ns.Window then ns.Window:BoostChanged() end  -- a filter: the list follows at once
        end)
        check.label = T.Text(panel, "small", "textDim")
        check.label:SetPoint("LEFT", check, "RIGHT", 6, 0)
        check.group = g
        panel.slotChecks[i] = check
    end
    local function All(on)
        for _, check in ipairs(panel.slotChecks) do
            ns.Boost.SetSlot(check.group.key, on)
            check:Set(on)
        end
        if ns.Window then ns.Window:BoostChanged() end
    end
    panel.allSlots = W.Button(panel, "", function() All(true) end)
    panel.noSlots = W.Button(panel, "", function() All(false) end)
    panel.go = W.Button(panel, "", function() panel.Start() end, "primary")
    panel.stop = W.Button(panel, "", function() panel.End() end)
    panel.min:SetScript("OnEnterPressed", function(self) self:ClearFocus() panel.Start() end)
    panel.min:SetScript("OnEscapePressed", function() Dialog.Hide() end)
end

local function Layout()
    local y = 14 + panel.title:GetStringHeight() + 4 + panel.spec:GetStringHeight() + 16
    panel.minLabel:ClearAllPoints()
    panel.minLabel:SetPoint("TOPLEFT", 16, -(y + 4))
    panel.min:ClearAllPoints()
    panel.min:SetPoint("TOPRIGHT", -16, -y)
    y = y + math.max(26, panel.minLabel:GetStringHeight() + 8) + 6
    panel.minHint:ClearAllPoints()
    panel.minHint:SetPoint("TOPLEFT", 16, -y)
    y = y + panel.minHint:GetStringHeight() + 14
    panel.locked:ClearAllPoints()
    panel.locked:SetPoint("TOPRIGHT", -16, -y)
    panel.lockedLabel:ClearAllPoints()
    panel.lockedLabel:SetPoint("TOPLEFT", 16, -(y + 3))
    y = y + math.max(20, panel.lockedLabel:GetStringHeight()) + 16
    panel.aheadLabel:ClearAllPoints()
    panel.aheadLabel:SetPoint("TOPLEFT", 16, -y)
    y = y + panel.aheadLabel:GetStringHeight() + 6
    panel.ahead:ClearAllPoints()
    panel.ahead:SetPoint("TOPLEFT", 16, -y)
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

function Dialog.Toggle(anchor, onStart, onEnd)
    if Dialog.IsShown() then Dialog.Hide() return end
    if not panel then Build() end
    local svc = Sendit.Service("upgrade")
    local active = ns.Boost.Active()
    panel.title:SetText(L.boost)
    panel.spec:SetText(svc and L.boostFor:format(svc.Spec() or "?") or L.boostNeedsUpgrade)
    panel.minLabel:SetText(L.boostMinLabel)
    panel.min:SetText((tostring(ns.Boost.Min()):gsub("%.", L.decimal)))
    panel.minHint:SetText(L.boostMinHint)
    panel.lockedLabel:SetText(L.boostLocked)
    panel.locked:Refresh()
    panel.aheadLabel:SetText(L.boostAhead)
    if panel.ahead.Refresh then panel.ahead:Refresh() end
    panel.slotTitle:SetText(L.boostSlots)
    for _, check in ipairs(panel.slotChecks) do
        check.label:SetText(ns.Boost.SlotLabel(check.group))
        check:Set(ns.Boost.Slot(check.group.key))
    end
    panel.allSlots:SetLabel(L.slotsAll)
    panel.noSlots:SetLabel(L.slotsNone)
    panel.go:SetLabel(active and L.boostAgain or L.boostGo)
    panel.go:SetEnabled(svc ~= nil)
    panel.stop:SetLabel(active and L.boostEnd or L.boostCancel)
    function panel.Start()
        local v = tonumber(((panel.min:GetText() or ""):gsub(",", ".")))
        if v then ns.Boost.SetMin(v) end
        Dialog.Hide()
        onStart()
    end
    function panel.End()
        Dialog.Hide()
        if ns.Boost.Active() then onEnd() end
    end
    Layout()
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6)
    anchorFrame = anchor
    panel:Show()
    T.FadeIn(panel, 0.12, 4)
    panel.min:SetFocus()
    panel.min:HighlightText()
end
function Dialog.Panel() return panel end  -- tests
