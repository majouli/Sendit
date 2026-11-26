--[[
  Window: two items side by side and the basis of the rating - Alt-click or drop items into the slots
  (right click clears; one item fills the other side with the worn one), spec buttons, the verdict
  (winner's gain), stat table, the metrics with each item and the assumptions. Measured layout;
  Escape closes, drag moves.
]]
local _, ns = ...
local L = ns.L
local T = Sendit.Theme

local Window = {}
ns.Window = Window

local MIN_W, MAX_W, PAD, ROW, GAP, MIN_COL = 470, 780, 14, 16, 20, 44
local CONTENT_TOP = 118  -- below title, spec buttons and item slots
local GREEN, RED, GREY, HEAD = "|cff40ff40", "|cffff5050", "|cff999999", "|cff66c2ff"

local frame
local links = {}
local pool = {}
local rows = {}
local specButtons = {}

local function Num(v, decimals)
    return ((("%." .. (decimals or 1) .. "f"):format(v)):gsub("%.", L.decimal))
end

local function Signed(v, decimals)
    return (v > 0 and "+" or "") .. Num(v, decimals)
end

local function Colored(v, text)
    local color = v > 0.0001 and GREEN or v < -0.0001 and RED or GREY
    return color .. text .. "|r"
end

local function Row(label, a, b, c) rows[#rows + 1] = { label, a, b, c } end
local function Text(text) rows[#rows + 1] = { text, wrap = true } end
local function Gap() rows[#rows + 1] = { gap = true } end

local function Pooled(i)
    local l = pool[i]
    if not l then
        l = { label = T.Text(frame.content, "small", "textDim") }
        l.label:SetJustifyH("LEFT")
        for c = 1, 3 do
            l[c] = T.Text(frame.content, "small", "text")
            l[c]:SetJustifyH("RIGHT")
        end
        pool[i] = l
    end
    return l
end

local function Width(fs)
    return fs:GetStringWidth() or 0
end

local function Layout()
    local labelW, colW = 0, { MIN_COL, MIN_COL, MIN_COL }
    for i, r in ipairs(rows) do
        local l = Pooled(i)
        l.label:SetWidth(0)  -- unconstrained: the measured width is the text's
        l.label:SetWordWrap(false)
        l.label:SetText(r.gap and "" or r[1] or "")
        for c = 1, 3 do l[c]:SetText((not r.wrap and r[c + 1]) or "") end
        if not r.wrap and not r.gap then
            labelW = math.max(labelW, Width(l.label))
            for c = 1, 3 do colW[c] = math.max(colW[c], Width(l[c])) end
        end
    end

    local width = labelW + 2 * PAD
    for c = 1, 3 do width = width + GAP + colW[c] end
    width = math.min(MAX_W, math.max(MIN_W, math.ceil(width)))
    local inner = width - 2 * PAD
    -- columns packed to the right edge; the label gets the rest
    local right = { [3] = inner }
    right[2] = right[3] - colW[3] - GAP
    right[1] = right[2] - colW[2] - GAP
    local labelRoom = right[1] - colW[1] - GAP

    local y = 0
    for i, r in ipairs(rows) do
        local l = pool[i]
        l.label:ClearAllPoints()
        l.label:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
        local h = ROW
        if r.gap then
            h = ROW / 2
        elseif r.wrap then
            l.label:SetWidth(inner)
            l.label:SetWordWrap(true)
            h = math.max(ROW, (l.label:GetStringHeight() or 0) + 4)
        else
            l.label:SetWidth(labelRoom)
            for c = 1, 3 do
                l[c]:ClearAllPoints()
                l[c]:SetPoint("TOPRIGHT", frame.content, "TOPLEFT", right[c], -y)
            end
        end
        y = y + h
    end
    for i = #rows + 1, #pool do
        pool[i].label:SetText("")
        for c = 1, 3 do pool[i][c]:SetText("") end
    end

    frame:SetSize(width, CONTENT_TOP + y + PAD)
    local nameW = width / 2 - PAD - 56
    for _, b in ipairs(frame.slots) do b.name:SetWidth(nameW) end
end

local function SlotButton(index)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(40, 40)
    if index == 1 then
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -64)
    else
        b:SetPoint("TOPLEFT", frame, "TOP", 4, -64)
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    T.Fill(b, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Border(b, "border")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.side = T.Text(frame, "caption", "textMuted")
    b.side:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, -1)
    b.side:SetText(index == 1 and L.left or L.right)
    b.name = T.Text(frame, "label", "text")
    b.name:SetWordWrap(true)
    b.name:SetPoint("TOPLEFT", b.side, "BOTTOMLEFT", 0, -2)
    b.name:SetJustifyH("LEFT")
    b.name:SetMaxLines(2)

    local function Drop()
        local kind, _, link = GetCursorInfo()
        if kind == "item" and link then
            ClearCursor()
            Window:SetItem(index, link)
        end
    end
    b:SetScript("OnReceiveDrag", Drop)
    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            Window:SetItem(index, nil)
        else
            Drop()
        end
    end)
    b:SetScript("OnEnter", function(self)
        if links[index] then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(links[index])
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function Pct(a, b)
    return b > 0 and (a / b - 1) * 100 or 0
end

-- "Left is better: +12,3% Damage" - the winner's gain, never negative
local function Verdict(ctx, r)
    local m = ctx.spec.primary
    local pct = Pct(r.ma.primary, r.mb.primary)
    if math.abs(pct) < 0.05 then
        Text(GREY .. L.verdictEqual:format(m.label) .. "|r")
    elseif pct > 0 then
        Text(GREEN .. L.verdictBetter:format(L.left, Signed(pct) .. "%", m.label) .. "|r")
    else
        Text(GREEN .. L.verdictBetter:format(L.right, Signed(Pct(r.mb.primary, r.ma.primary)) .. "%", m.label) .. "|r")
    end
    Text(GREY .. L.verdictBasis:format(L.specs[ctx.specKey], m.label, m.unit, ctx.spec.secondary.label) .. "|r")
end

-- stat differences stay uncoloured: more of a stat is not better for every spec
local function StatRows(a, b)
    local keys, seen = {}, {}
    for _, item in ipairs({ a, b }) do
        for k in pairs(item.stats) do
            if not seen[k] then
                seen[k] = true
                keys[#keys + 1] = k
            end
        end
    end
    table.sort(keys, function(x, y) return (ns.StatNames[x] or x) < (ns.StatNames[y] or y) end)
    for _, k in ipairs(keys) do
        local va, vb = a.stats[k] or 0, b.stats[k] or 0
        local d = k == "procDps" and 1 or 0
        Row(ns.StatNames[k] or k, Num(va, d), Num(vb, d), Signed(va - vb, d))
    end
    if a.weapon or b.weapon then
        local da = a.weapon and a.weapon.dps or 0
        local db = b.weapon and b.weapon.dps or 0
        Row(L.weapon .. " (DPS)", Num(da), Num(db), Signed(da - db))
    end
end

local function Metric(metric, va, vb)
    local d = metric.unit == "EHP" and 0 or 1
    local pct = Pct(va, vb)
    Row(metric.label .. " (" .. metric.unit .. ")", Num(va, d), Num(vb, d), Colored(pct, Signed(pct) .. "%"))
end

local function Assumptions(ctx, a, b)
    Text(HEAD .. L.assumptions .. "|r")
    local s = ctx.s
    Text(GREY .. L.target:format(ns.Model.TargetLevel(s)) .. "|r")
    Text(GREY .. L.agiPerCrit:format(s.agiPerCrit, s.measured.agi and L.calibrated or L.estimated) .. "|r")
    Text(GREY .. L.intPerCrit:format(s.intPerSpellCrit, s.measured.int and L.calibrated or L.estimated) .. "|r")
    if ctx.spec.mana then Text(GREY .. L.fight:format(ns.Model.PULL_GAP) .. "|r") end
    local level = ns.Model.TargetLevel(s)
    Text(GREY .. L.mobArmor:format(level, ns.Mobs.Armor(level)) .. "|r")
    if (a.stats.procDps or 0) > 0 or (b.stats.procDps or 0) > 0 then
        local item = (a.stats.procDps or 0) > 0 and a or b
        local ppm = item.procPpm or ns.Stats.PROCS_PER_MINUTE
        Text(GREY .. (item.procKnown and L.procKnown or L.procNote):format(ppm) .. "|r")
    end
    for _, item in ipairs({ a, b }) do
        for _, text in ipairs(item.effects) do
            Text(GREY .. L.effects .. " (" .. item.name .. "): " .. text .. "|r")
        end
        for _, text in ipairs(item.unrated) do
            Text(GREY .. L.unrated .. " (" .. item.name .. "): " .. text .. "|r")
        end
    end
end

local function UpdateSlots()
    for index, b in ipairs(frame.slots) do
        local item = links[index] and ns.Stats.Read(links[index])
        b.icon:SetTexture(item and item.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        b.name:SetText(item and item.name or L.dropHere)
    end
end

local function UpdateSpecButtons(ctx)
    for _, b in ipairs(specButtons) do b:Hide() end
    if not ctx then return end
    local keys = { "AUTO" }
    for _, k in ipairs(ctx.classData.order) do keys[#keys + 1] = k end
    local x = PAD
    for i, key in ipairs(keys) do
        local b = specButtons[i]
        if not b then
            b = CreateFrame("Button", nil, frame)
            b:SetHeight(18)
            b.bg = T.Fill(b, "selected", "BACKGROUND")
            b.bg:SetAllPoints()
            T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
            b.text = T.Text(b, "small", "textDim")
            b.text:SetPoint("CENTER")
            specButtons[i] = b
        end
        b.text:SetText(key == "AUTO" and ns.AutoLabel(ctx) or L.specs[key])
        b:SetWidth(math.max(80, Width(b.text) + 20))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, -34)
        x = x + b:GetWidth() + 4
        local active = (key == "AUTO" and not ns.charDB.spec) or ns.charDB.spec == key
        T.Paint(b.text, active and "accent" or "textDim")
        b:SetScript("OnClick", function()
            ns.SetSpec(key ~= "AUTO" and key or nil)
        end)
        b:Show()
    end
end

function Window:Refresh()
    if not frame or not frame:IsShown() then return end
    UpdateSlots()
    local ctx, reason = ns.Compare.Context()
    UpdateSpecButtons(ctx)
    wipe(rows)
    if not ctx then
        Text(reason == "unsupported" and L.noClass or L.noData)
    elseif links[1] and links[2] then
        local r = ns.Compare.Pair(links[1], links[2])
        if r.status == "ok" then
            Verdict(ctx, r)
            Gap()
            Row("", L.left, L.right, L.diff)
            StatRows(r.a, r.b)
            Gap()
            Text(HEAD .. L.result .. " (" .. L.specs[ctx.specKey] .. ")|r")
            Metric(ctx.spec.primary, r.ma.primary, r.mb.primary)
            Metric(ctx.spec.secondary, r.ma.secondary, r.mb.secondary)
            Gap()
            Assumptions(ctx, r.a, r.b)
        else
            Text(GREY .. (r.status == "differentSlots" and L.differentSlots or L.noCompare) .. "|r")
        end
    else
        Text(GREY .. L.dropHere .. "|r")
    end
    Layout()
end

function Window:SetItem(index, link)
    links[index] = link
    if index == 1 and link and not links[2] then
        local item = ns.Stats.Read(link)
        local slots = item and ns.Compare.SlotsFor(item)
        local equipped = slots and GetInventoryItemLink("player", slots[1])
        if equipped and equipped ~= link then links[2] = equipped end
    end
    self:Refresh()
end

local function Create()
    frame = CreateFrame("Frame", "SenditUpgradeWindow", UIParent)
    frame:SetSize(MIN_W, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "SenditUpgradeWindow")

    T.Fill(frame, "bg", "BACKGROUND"):SetAllPoints()
    local edges = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, e in ipairs(edges) do e:SetShown(not on) end
    end })

    local title = T.Text(frame, "title", "accent")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L.title)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    frame.slots = { SlotButton(1), SlotButton(2) }
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", PAD, -CONTENT_TOP)
    frame.content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    frame:SetScript("OnShow", function() Window:Refresh() end)
end

function Window:Compare(link)
    if not frame then Create() end
    links[1], links[2] = nil, nil
    frame:Show()
    frame:Raise()
    self:SetItem(1, link)
end

function Window:Items() return links[1], links[2] end

function Window:Toggle()
    if not frame then Create() end
    frame:SetShown(not frame:IsShown())
end

function Window:IsShown()
    return frame ~= nil and frame:IsShown()
end

Sendit:AddLauncher({
    module = ns.module,
    key = "upgrade", order = 20, icon = "Interface\\AddOns\\Sendit_Upgrade\\Media\\Icon", title = "Upgrade",
    toggle = function() Window:Toggle() end,
    shown = function() return Window:IsShown() end,
})
