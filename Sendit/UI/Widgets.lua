--[[
  Widgets: the control kit of the window and module pages, painted through the Theme. Value controls
  take a getter and a setter and have :Refresh().
  Switch, Slider, Button ("primary"), Segmented, Chevron, ShowMenu, Dropdown, Movable, Value, Inline,
  Check, Search, ScrollArea
]]
local _, ns = ...

local W = {}
ns.Widgets = W

local T = ns.Theme
local SIZE = T.SIZE

local function Hover(frame, color)
    T.Fill(frame, color or "hover", "HIGHLIGHT"):SetAllPoints()
end

local function ClickSound()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
end

local function ToggleSound()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function W.Switch(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(36, 20)
    b.track = T.Pill(b, "toggle", 36, 20, "ARTWORK", 0)
    b.track:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.knob = T.Circle(b, "text", 14, "ARTWORK", 2)

    function b:Refresh()
        local on = get() and true or false
        self.track:Paint(on and "accent" or "toggle")
        T.Paint(self.knob, on and "onAccent" or "textDim")
        self.knob:ClearAllPoints()
        self.knob:SetPoint("CENTER", self, on and "RIGHT" or "LEFT", on and -10 or 10, 0)
    end
    b:SetScript("OnClick", function(self)
        set(not get())
        ToggleSound()
        self:Refresh()
    end)
    b:Refresh()
    return b
end

function W.Slider(parent, lo, hi, step, get, set, fmt, width)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width or 180, 16)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)

    local track = T.Fill(s, "track", "ARTWORK", 0)
    track:SetHeight(4)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)

    local thumb = T.Circle(s, "text", 14, "OVERLAY", 1)
    s:SetThumbTexture(thumb)

    local fill = T.Fill(s, "accent", "ARTWORK", 1)
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")

    s.value = T.Text(s, "label", "textDim")
    s.value:SetPoint("RIGHT", s, "LEFT", -12, 0)
    s.value:SetJustifyH("RIGHT")

    local refreshing = false
    local function Show(v) s.value:SetText(fmt and fmt(v) or tostring(v)) end

    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        Show(v)
        if not refreshing then set(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(math.min(hi, math.max(lo, self:GetValue() + delta * step)))
    end)

    function s:Refresh()
        refreshing = true
        self:SetValue(get())
        refreshing = false
        Show(get())
    end
    s:Refresh()
    return s
end

function W.Button(parent, text, onClick, style)
    local primary = style == "primary"
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(28)
    T.Fill(b, primary and "accent" or "panelAlt", "BACKGROUND"):SetAllPoints()
    if not primary then T.Border(b, "border") end
    Hover(b, primary and "selected" or "hover")
    b.text = T.Text(b, "label", primary and "onAccent" or "text")
    if primary then T.NoShadow(b.text) end
    b.text:SetPoint("CENTER")
    function b:SetLabel(t)
        self.text:SetText(t)
        self:SetWidth(math.max(80, self.text:GetStringWidth() + 28))
    end
    b:SetLabel(text)
    function b.Refresh() end  -- lets a button sit in a Layout row
    b:SetScript("OnClick", function(self, ...)
        ClickSound()
        onClick(self, ...)
    end)
    return b
end

-- Segmented: options = { { value, text } } (text may be a function)
function W.Segmented(parent, options, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(28)
    T.Fill(f, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Border(f, "border")
    f.buttons = {}
    local x = 1
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b.value = opt[1]
        b.sel = T.Fill(b, "accent", "ARTWORK")
        b.sel:SetAllPoints()
        T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
        b.text = T.Text(b, "label", "textDim")
        T.NoShadow(b.text)
        b.text:SetPoint("CENTER")
        b.label = opt[2]
        b:SetScript("OnClick", function(self)
            ClickSound()
            set(self.value)
            f:Refresh()
        end)
        f.buttons[i] = b
    end
    function f:Refresh()
        local v = get()
        local x = 1
        for _, b in ipairs(self.buttons) do
            b.text:SetText(ns.Locale.Resolve(b.label))
            b:SetSize(b.text:GetStringWidth() + 28, 26)
            b:ClearAllPoints()
            b:SetPoint("LEFT", x, 0)
            x = x + b:GetWidth()
            local on = b.value == v
            b.sel:SetShown(on)
            T.Paint(b.text, on and "onAccent" or "textDim")
        end
        self:SetWidth(x + 1)
    end
    f:Refresh()
    return f
end

-- Chevron: two rotated hairlines; dir "down" | "up" | "left" | "right"
local CHEVRON = {  -- per direction: { x, y, angle } of both lines
    down = { { -2, 0, -45 }, { 2, 0, 45 } }, up = { { -2, 0, 45 }, { 2, 0, -45 } },
    right = { { 0, 2, -45 }, { 0, -2, 45 } }, left = { { 0, 2, 45 }, { 0, -2, -45 } },
}
function W.Chevron(parent, color, dir)
    local f = CreateFrame("Frame", nil, parent)
    local lines = CHEVRON[dir] or CHEVRON.down
    if lines[1][1] == 0 then f:SetSize(5, 8) else f:SetSize(8, 5) end
    f.lines = {}
    for i = 1, #lines do
        local line = T.Fill(f, color, "ARTWORK")
        line:SetSize(6, 1.5)
        f.lines[i] = line
    end
    function f:Point(d)
        for i, l in ipairs(CHEVRON[d] or CHEVRON.down) do
            self.lines[i]:ClearAllPoints()
            self.lines[i]:SetPoint("CENTER", l[1], l[2])
            self.lines[i]:SetRotation(math.rad(l[3]))
        end
    end
    f:Point(dir)
    return f
end

-- W.ShowMenu(anchor, { { value, text } }, current, onSelect); a click elsewhere closes it
local menu, catcher

local function HideMenu()
    if catcher then catcher:Hide() end
end

local function BuildMenu()
    catcher = CreateFrame("Button", nil, UIParent)
    ns.ownFrames[catcher] = true
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetScript("OnClick", HideMenu)
    catcher:Hide()
    menu = CreateFrame("Frame", nil, catcher)
    menu:SetFrameLevel(catcher:GetFrameLevel() + 5)
    menu:EnableMouse(true)
    T.Fill(menu, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(menu, "border")
    menu.items = {}
end

function W.ShowMenu(anchor, options, current, onSelect)
    if not menu then BuildMenu() end
    local width = 150
    for i, opt in ipairs(options) do
        local b = menu.items[i]
        if not b then
            b = CreateFrame("Button", nil, menu)
            b:SetHeight(26)
            b:SetPoint("TOPLEFT", 1, -4 - (i - 1) * 26)
            b:SetPoint("RIGHT", -1, 0)
            T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
            b.dot = T.Fill(b, "accent", "ARTWORK")
            b.dot:SetSize(4, 4)
            b.dot:SetPoint("LEFT", 10, 0)
            b.text = T.Text(b, "label", "text")
            b.text:SetPoint("LEFT", 22, 0)
            menu.items[i] = b
        end
        b.text:SetText(opt[2])
        width = math.max(width, b.text:GetStringWidth() + 44)
        local on = opt[1] == current
        b.dot:SetShown(on)
        T.Paint(b.text, on and "accent" or "text")
        b:SetScript("OnClick", function()
            ClickSound()
            HideMenu()
            onSelect(opt[1])
        end)
        b:Show()
    end
    for i = #options + 1, #menu.items do menu.items[i]:Hide() end
    menu:SetSize(width, #options * 26 + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    catcher:Show()
    T.FadeIn(menu, 0.12, 4)
end

-- Dropdown: options() -> { { value, text } } each time it opens
function W.Dropdown(parent, width, options, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 28)
    T.Fill(b, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Border(b, "border")
    Hover(b)
    b.text = T.Text(b, "label", "text")
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetPoint("RIGHT", -24, 0)
    W.Chevron(b, "textDim"):SetPoint("RIGHT", -10, 0)
    function b:Refresh()
        local current = get()
        local label = current or ""
        for _, opt in ipairs(options()) do
            if opt[1] == current then label = opt[2] end
        end
        self.text:SetText(label)
    end
    b:SetScript("OnClick", function(self)
        ClickSound()
        W.ShowMenu(self, options(), get(), function(value)
            set(value)
            self:Refresh()
        end)
    end)
    b:Refresh()
    return b
end

-- Movable(frame, handle, { store, key, default, canMove(), onDrop() }) -> Restore()
function W.Movable(frame, handle, opts)
    opts = opts or {}
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    local function Restore()
        local p = opts.store and opts.store[opts.key] or opts.default
        if not p then return end
        frame:ClearAllPoints()
        frame:SetPoint(p[1], frame:GetParent(), p[2], p[3], p[4])
    end
    handle:SetScript("OnDragStart", function()
        if opts.canMove and not opts.canMove() then return end
        frame:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if opts.store then
            local point, _, relPoint, x, y = frame:GetPoint(1)
            opts.store[opts.key] = { point, relPoint, x, y }
            Restore()  -- StartMoving may re-anchor to UIParent: keep the parent
        end
        if opts.onDrop then opts.onDrop() end
    end)
    Restore()
    return Restore
end

function W.Value(parent, width, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 28)
    f.text = T.Text(f, "label", "accent")
    f.text:SetAllPoints()
    f.text:SetJustifyH("RIGHT")
    function f:Refresh() self.text:SetText(text() or "") end
    f:Refresh()
    return f
end

function W.Inline(parent, widgets, gap)
    local f = CreateFrame("Frame", nil, parent)
    local x, h = 0, 0
    for i, w in ipairs(widgets) do
        w:SetParent(f)
        w:ClearAllPoints()
        w:SetPoint("LEFT", x, 0)
        x = x + w:GetWidth() + (i < #widgets and (gap or 8) or 0)
        h = math.max(h, w:GetHeight())
    end
    f:SetSize(x, h)
    function f:Refresh()
        for _, w in ipairs(widgets) do
            if w.Refresh then w:Refresh() end
        end
    end
    return f
end

function W.Check(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    T.Border(b, "box")
    b.fill = T.Fill(b, "accent", "ARTWORK")
    b.fill:SetAllPoints()
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b.mark:SetPoint("CENTER")
    b.mark:SetSize(18, 18)
    T.Paint(b.mark, "onAccent")
    Hover(b)
    function b:Set(checked, locked)
        self.checked = checked
        self.fill:SetShown(checked)
        self.mark:SetShown(checked)
        self:SetEnabled(not locked)
        self:SetAlpha(locked and 0.35 or 1)
    end
    b:SetScript("OnClick", function(self)
        ToggleSound()
        onClick(self, not self.checked)
    end)
    return b
end

function W.Search(parent, placeholder, onChange)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetHeight(28)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetTextInsets(10, 10, 0, 0)
    T.Paint(e, "text")
    T.Fill(e, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Border(e, "border")
    e.hint = T.Text(e, "label", "textMuted")
    e.hint:SetPoint("LEFT", 10, 0)
    e.hint:SetText(placeholder)
    e:SetScript("OnTextChanged", function(self)
        self.hint:SetShown(self:GetText() == "")
        onChange(self:GetText())
    end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return e
end

function W.ScrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
    end)
    sf.content = content
    return sf
end
