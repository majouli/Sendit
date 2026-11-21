--[[
  Detail: one card per catalog group (only the picked one shown) - a header with icon, name and level,
  then a row per CVar: label, CVar name, live value with its change against the client default, the
  control (wide slider, switch or choice) and a reset button (dim while the profile holds no value).
  ns.Detail(parent, ctx) -> detail;  ctx = { Mode() -> mode, Changed() }
  detail:Show(key) / Refresh() / Height() / entries = { { section, label, desc, row } } (search)
]]
local _, ns = ...
local L = ns.L
local T, W = Sendit.Theme, Sendit.Widgets
local CVars = ns.CVars
local function Tx(key) return Sendit.Locale.Text(L, key) end

local HEAD, ROW_H, PAD, LABEL_W, VALUE_W = 60, 54, 20, 210, 58
local RESET_ICON = "Interface\\Buttons\\UI-RefreshButton"

local function Number(e, v)
    if v == nil then return "-" end
    if e.kind ~= "range" or e.step >= 1 then return ("%d"):format(v) end
    return ("%.2f"):format(v)
end

local function Default(e, mode)
    local ok, v = pcall(GetCVarDefault, CVars.Name(e, mode))
    if ok and type(v) == "string" then return tonumber(v) end
end

-- "! " in the warning colour (inline: follows the label wherever it wraps)
local function Bang()
    local r, g, b = T.Color("warning")
    return ("|cff%02x%02x%02x!|r  "):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function ShowTip(owner, e, ctx)
    local mode = ctx.Mode()
    local tt = GameTooltip
    tt:SetOwner(owner, "ANCHOR_RIGHT")
    tt:SetText(L[e.cvar], T.Color("text"))
    local r, g, b = T.Color("textDim")
    tt:AddLine(ns.Tips[e.cvar], r, g, b, true)
    r, g, b = T.Color("textMuted")
    local d = Default(e, mode)
    if d then tt:AddLine(ns.Tips.default:format(Number(e, d)), r, g, b) end
    if e.kind == "range" then tt:AddLine(ns.Tips.range:format(Number(e, e.lo), Number(e, e.hi)), r, g, b) end
    if e.menu then tt:AddLine(ns.Tips.menuTop:format(Number(e, e.menu)), r, g, b) end
    if e.cost then
        local text
        if e.kind == "switch" then text = ns.Tips.costOff
        elseif e.best == "lo" then text = ns.Tips.costBelow:format(Number(e, e.cost))
        else text = ns.Tips.costFrom:format(Number(e, e.cost)) end
        r, g, b = T.Color("warning")
        tt:AddLine(text .. " " .. (e.src == "guide" and ns.Tips.srcGuide or ns.Tips.srcEstimate), r, g, b, true)
    end
    tt:Show()
end

local function Tip(frame, e, ctx)
    frame:HookScript("OnEnter", function(self) ShowTip(self, e, ctx) end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ResetButton(row, e, ctx)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(24, 24)
    T.Circle(b, "panelAlt", 24, "BACKGROUND")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(RESET_ICON)
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    T.Circle(b, "hover", 24, "HIGHLIGHT")
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        CVars.Reset(e, ctx.Mode())
        ctx.Changed()
    end)
    function b:Refresh()
        local owned = CVars.Owned(e, ctx.Mode())
        self:SetEnabled(owned)
        self:SetAlpha(owned and 1 or 0.25)
    end
    return b
end

local function Row(card, e, ctx, y)
    local row = CreateFrame("Frame", nil, card)
    local h = ROW_H
    row:SetHeight(h)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", card, "RIGHT")
    local line = T.Fill(row, "divider", "BORDER")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", PAD, 0)
    line:SetPoint("TOPRIGHT", -PAD, 0)

    row.label = T.Text(row, "label", "text")
    row.label:SetPoint("TOPLEFT", PAD, -10)
    row.label:SetWidth(LABEL_W)
    row.label:SetWordWrap(true)
    row.label:SetMaxLines(2)
    row.cvar = T.Text(row, "caption", "textMuted")
    row.cvar:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
    row.cvar:SetText(e.cvar)

    local reset = ResetButton(row, e, ctx)
    local function get() return CVars.Get(e, ctx.Mode()) end
    local function set(v)
        CVars.Set(e, ctx.Mode(), v)
        ctx.Changed()
    end

    reset:SetPoint("RIGHT", -PAD + 4, 0)
    local control
    if e.kind == "range" then
        row.value = T.Text(row, "title", "accent")
        row.value:SetPoint("TOPRIGHT", reset, "TOPLEFT", -12, 2)
        row.value:SetWidth(VALUE_W)
        row.value:SetJustifyH("RIGHT")
        row.delta = T.Text(row, "caption", "success")
        row.delta:SetPoint("TOPRIGHT", row.value, "BOTTOMRIGHT", 0, -2)
        control = ns.Slider(row, e, get, set, function() return Default(e, ctx.Mode()) end)
        control:SetPoint("LEFT", PAD + LABEL_W + 16, 0)
        control:SetPoint("RIGHT", reset, "LEFT", -VALUE_W - 24, 0)
    else
        if e.kind == "switch" then
            control = W.Switch(row, function() return get() == 1 end, function(on) set(on and 1 or 0) end)
        else
            local options = {}
            for i, v in ipairs(e.choices) do options[i] = { v, tostring(v) } end
            control = W.Segmented(row, options, get, set)
        end
        control:SetPoint("RIGHT", reset, "LEFT", -14, 0)
    end

    row:EnableMouse(true)
    Tip(row, e, ctx)
    Tip(control, e, ctx)

    function row:Refresh()
        self.label:SetText(e.cost and (Bang() .. L[e.cvar]) or L[e.cvar])
        local mode = ctx.Mode()
        local suffix = (mode == "raid" and not e.raid) and ("  ·  " .. L.both) or ""
        self.cvar:SetText(CVars.Name(e, mode) .. suffix)
        control:Refresh()
        reset:Refresh()
        if self.value then
            local v, d = get(), Default(e, mode)
            self.value:SetText(Number(e, v))
            T.Paint(self.value, ns.Costly(e, v) and "warning" or "accent")
            local text = ""
            if v and d and d > 0 and math.abs(v - d) > 1e-6 then
                local pct = (v / d - 1) * 100
                text = ("%s%d %%"):format(pct > 0 and "+" or "-", math.floor(math.abs(pct) + 0.5))
                local better = (ns.Best(e) == e.lo) == (v < d)
                T.Paint(self.delta, better and "success" or "textMuted")
            end
            self.delta:SetText(text)
        end
    end
    return row, h
end

local function Card(parent, group, ctx, entries)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT")
    card:SetPoint("RIGHT")
    T.Fill(card, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(card, "border")

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(group.icon)
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", PAD, -16)
    local title = T.Text(card, "title", "text")
    title:SetPoint("LEFT", icon, "RIGHT", 12, 0)
    local level = T.Text(card, "title", "accent")
    level:SetPoint("TOPRIGHT", -PAD, -22)
    level:SetJustifyH("RIGHT")

    local rows, y = {}, HEAD
    for _, e in ipairs(group.entries) do
        local row, h = Row(card, e, ctx, y)
        row.group = group.key
        row.cardTop = y
        rows[#rows + 1] = row
        entries[#entries + 1] = { section = Tx(group.key), label = Tx(e.cvar), desc = e.cvar, row = row }
        y = y + h
    end
    card:SetHeight(y + 8)

    function card:Refresh()
        title:SetText(L[group.key])
        local x = ns.GroupLevel(group, ctx.Mode())
        level:SetText(x and ("%d %%"):format(math.floor(x * 100 + 0.5)) or "")
        for _, r in ipairs(rows) do r:Refresh() end
    end
    return card
end

function ns.Detail(parent, ctx)
    local d = CreateFrame("Frame", nil, parent)
    d.entries, d.cards = {}, {}
    for _, group in ipairs(ns.Catalog) do
        local card = Card(d, group, ctx, d.entries)
        card:Hide()
        d.cards[group.key] = card
    end

    function d:Show(key)
        for k, card in pairs(self.cards) do card:SetShown(k == key) end
        self.current = key
        local card = self.cards[key]
        if card then
            card:Refresh()
            T.FadeIn(card, 0.15)
        end
    end

    function d:Height()
        local card = self.cards[self.current]
        return card and card:GetHeight() or 0
    end

    function d:Refresh()
        local card = self.cards[self.current]
        if card then card:Refresh() end
    end
    return d
end
