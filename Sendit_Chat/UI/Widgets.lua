--[[
  Widgets: the chat's controls in its look; texts may be a locale key or a function (read when shown).
  Text(v) / IconButton(parent, kind, tip, onClick) / Badge(parent) / Slider(...) / Switch(...) /
  Button(...) / Input(parent, placeholder, size) / Grip(frame, onDone) /
  Menu(items) (at the cursor; item = { text, fn [, checked] }) /
  Drag(handle, frame, canMove, onDone)
]]
local _, ns = ...
local T = ns.Theme

local Widgets = {}
ns.Widgets = Widgets

function Widgets.Text(v)
    if type(v) == "function" then return v() end
    if type(v) == "string" and v:match("^[A-Z][A-Z0-9_]*$") then return ns.L[v] end
    return v
end

local function Tip(owner, text)
    if not text then return end
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Widgets.Text(text), 1, 1, 1)
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function Widgets.IconButton(parent, kind, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    T.Icon(b, kind, "textMuted")
    b.kind = kind
    b:SetScript("OnEnter", function(self) T.IconColor(self, "accent") end)
    b:SetScript("OnLeave", function(self) T.IconColor(self, self.active and "accent" or "textMuted") end)
    b:SetScript("OnClick", function(self, button) if onClick then onClick(self, button) end end)
    function b.SetKind(self, k)
        self.kind = k
        T.Icon(self, k, self:IsMouseOver() and "accent" or (self.active and "accent" or "textMuted"))
    end
    Tip(b, tip)
    return b
end

function Widgets.Badge(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(16, 14)
    f.bg = T.Tex(f, "OVERLAY", "accent", 1)
    f.bg:SetAllPoints()
    f.text = T.Text(f, 9, "onAccent")
    f.text:SetDrawLayer("OVERLAY", 7)
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetShadowColor(0, 0, 0, 0)
    -- a gentle pulse while something is unread
    f.anim = f:CreateAnimationGroup()
    f.anim:SetLooping("BOUNCE")
    local pulse = f.anim:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.45)
    pulse:SetDuration(0.8)
    pulse:SetSmoothing("IN_OUT")
    function f.Set(self, n)
        if not n or n <= 0 then
            self.anim:Stop()
            self:Hide()
            return
        end
        local s = n > 99 and "99+" or tostring(n)
        self.text:SetText(s)
        self:SetWidth(math.max(14, #s * 6 + 6))
        self:Show()
        self.anim:Play()
    end
    f:Hide()
    return f
end

function Widgets.Slider(parent, label, min, max, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(220, 38)
    f.label = T.Text(f, 11, "textDim")
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label)
    f.value = T.Text(f, 11, "text")
    f.value:SetPoint("TOPRIGHT")
    f.value:SetJustifyH("RIGHT")
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("BOTTOMLEFT", 0, 4)
    s:SetPoint("BOTTOMRIGHT", 0, 4)
    s:SetHeight(14)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    local track = T.Tex(s, "BACKGROUND", "ink", 0.14)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(2)
    s.fill = T.Tex(s, "ARTWORK", "accent", 0.9)
    s.fill:SetPoint("LEFT"); s.fill:SetHeight(2)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(T.WHITE)
    thumb:SetSize(8, 12)
    T.Color(thumb, "accent")
    s:SetThumbTexture(thumb)
    local function Show(v)
        f.value:SetText(fmt and fmt(v) or tostring(v))
        local w = s:GetWidth() or 0
        s.fill:SetWidth(math.max(1, w * (v - min) / math.max(1e-6, max - min)))
    end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        Show(v)
        if v ~= get() then set(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
    s:SetScript("OnSizeChanged", function() Show(get()) end)
    function f.Refresh() s:SetValue(get()); Show(get()) end
    f.slider = s
    return f
end

function Widgets.Switch(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(220, 22)
    b.label = T.Text(b, 11, "textDim")
    b.label:SetPoint("LEFT")
    b.label:SetText(label)
    local track = CreateFrame("Frame", nil, b)
    track:SetSize(28, 14)
    track:SetPoint("RIGHT")
    track.bg = T.Tex(track, "ARTWORK", "ink", 0.14)
    track.bg:SetAllPoints()
    local knob = T.Tex(track, "OVERLAY", "text", 1)
    knob:SetSize(10, 10)
    function b.Refresh()
        local on = get() and true or false
        knob:ClearAllPoints()
        knob:SetPoint(on and "RIGHT" or "LEFT", on and -2 or 2, 0)
        if on then T.Color(track.bg, "accent", 0.9) else T.Color(track.bg, "ink", 0.14) end
        T.Color(knob, on and "onAccent" or "textMuted")
    end
    b:SetScript("OnClick", function()
        set(not get())
        b.Refresh()
    end)
    b.Refresh()
    return b
end

-- label over choices side by side
function Widgets.Segmented(parent, label, options, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(220, 42)
    f.label = T.Text(f, 11, "textDim")
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label)
    f.buttons = {}
    local n = #options
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(22)
        b.bg = T.Tex(b, "BACKGROUND", "ink", 0.08)
        b.bg:SetAllPoints()
        b.text = T.Text(b, 11, "textDim")
        b.text:SetPoint("CENTER")
        b.text:SetJustifyH("CENTER")
        b.text:SetText(opt[2])
        b.value = opt[1]
        b:SetScript("OnClick", function()
            if get() ~= opt[1] then set(opt[1]) end
            f.Refresh()
        end)
        f.buttons[i] = b
    end
    f:SetScript("OnSizeChanged", function(self)
        local w = (self:GetWidth() or 220) / n
        for i, b in ipairs(self.buttons) do
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * w, 0)
            b:SetWidth(w - (i < n and 2 or 0))
        end
    end)
    function f.Refresh()
        local v = get()
        for _, b in ipairs(f.buttons) do
            local on = b.value == v
            T.Color(b.bg, on and "accent" or "ink", on and 0.9 or 0.08)
            T.Color(b.text, on and "onAccent" or "textDim")
        end
    end
    f:GetScript("OnSizeChanged")(f)
    f.Refresh()
    return f
end

function Widgets.Button(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(220, 24)
    b.bg = T.Tex(b, "BACKGROUND", "ink", 0.08)
    b.bg:SetAllPoints()
    b.text = T.Text(b, 11, "text")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnEnter", function(self) T.Color(self.bg, "ink", 0.14) end)
    b:SetScript("OnLeave", function(self) T.Color(self.bg, "ink", 0.08) end)
    b:SetScript("OnClick", function() if onClick then onClick() end end)
    return b
end

function Widgets.Input(parent, placeholder, size)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetAutoFocus(false)
    T.SetFont(eb, size or 12, true)
    eb:SetTextInsets(8, 8, 0, 0)
    T.Color(eb, "text")
    eb.bg = T.Tex(eb, "BACKGROUND", "ink", 0.06)
    eb.bg:SetAllPoints()
    eb.hint = T.Text(eb, size or 12, "textMuted", "ARTWORK", true)
    eb.hint:SetPoint("LEFT", 8, 0)
    function eb.SetPlaceholder(self, v)
        self.placeholder = v
        self.hint:SetText(Widgets.Text(v) or "")
    end
    eb:SetPlaceholder(placeholder)
    eb:HookScript("OnShow", function(self) self:SetPlaceholder(self.placeholder) end)
    local function Hint()
        local t = eb:GetText()
        eb.hint:SetShown(t == nil or t == "")
    end
    eb:SetScript("OnTextChanged", Hint)
    eb:HookScript("OnEditFocusGained", function(self) T.Color(self.bg, "ink", 0.10) end)
    eb:HookScript("OnEditFocusLost", function(self) T.Color(self.bg, "ink", 0.06) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    function eb.SetSize2(self, s)
        T.SetFont(self, s, true)
        T.SetFont(self.hint, s, true)
    end
    return eb
end

function Widgets.Grip(frame, onDone)
    local g = CreateFrame("Button", nil, frame)
    g:SetSize(14, 14)
    g:SetPoint("BOTTOMRIGHT", -1, 1)
    g:SetFrameLevel(frame:GetFrameLevel() + 20)
    local lines = { { 5, -6, 6, -5 }, { 1, -6, 6, -1 }, { -3, -6, 6, 3 } }
    g.senditLines = {}
    for i, seg in ipairs(lines) do
        local l = g:CreateLine(nil, "OVERLAY")
        l:SetThickness(1)
        l:SetTexture(T.WHITE)
        l:SetStartPoint("CENTER", g, seg[1], seg[2])
        l:SetEndPoint("CENTER", g, seg[3], seg[4])
        g.senditLines[i] = l
    end
    g.senditIconCount = #lines
    T.IconColor(g, "textMuted", 0.6)
    g:SetScript("OnEnter", function(self) T.IconColor(self, "accent") end)
    g:SetScript("OnLeave", function(self) T.IconColor(self, "textMuted", 0.6) end)
    g:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    g:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if onDone then onDone() end
    end)
    return g
end

function Widgets.Drag(handle, frame, canMove, onDone)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if canMove() then frame:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if onDone then onDone() end
    end)
end

-- bounds for resizable frames
function Widgets.Bounds(frame, minW, minH, maxW, maxH)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW, maxH)
    end
end

local menu
local function BuildMenu()
    menu = T.Panel(UIParent, "FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    T.Decorate(menu, "panel")
    menu.items = {}
    ns.Listen("GLOBAL_MOUSE_DOWN", function()
        if menu:IsShown() and not menu:IsMouseOver() then menu:Hide() end
    end)
end

function Widgets.Menu(items)
    if not menu then BuildMenu() end
    local width = 160
    for i, item in ipairs(items) do
        local b = menu.items[i]
        if not b then
            b = CreateFrame("Button", nil, menu)
            b:SetHeight(22)
            b.hl = T.Tex(b, "BACKGROUND", "ink", 0)
            b.hl:SetAllPoints()
            b.text = T.Text(b, 11, "text")
            b.text:SetPoint("LEFT", 10, 0)
            b.box = CreateFrame("Frame", nil, b)
            b.box:SetSize(12, 12)
            b.box:SetPoint("RIGHT", -10, 0)
            T.Border(b.box, 1, "textMuted", 0.7)
            b.check = b.box:CreateTexture(nil, "OVERLAY")
            b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            b.check:SetPoint("CENTER")
            b.check:SetSize(16, 16)
            b:SetScript("OnEnter", function(self) T.Color(self.hl, "ink", 0.08) end)
            b:SetScript("OnLeave", function(self) T.Color(self.hl, "ink", 0) end)
            menu.items[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 1, -4 - (i - 1) * 22)
        b:SetPoint("TOPRIGHT", -1, -4 - (i - 1) * 22)
        b.text:SetText(item[1])
        b.box:SetShown(item[3] ~= nil)
        b.check:SetShown(item[3] == true)
        width = math.max(width, (b.text:GetStringWidth() or 0) + (item[3] ~= nil and 46 or 24))
        b:SetScript("OnClick", function()
            menu:Hide()
            item[2]()
        end)
        b:Show()
    end
    for i = #items + 1, #menu.items do menu.items[i]:Hide() end
    menu:SetSize(width, #items * 22 + 8)
    menu:ClearAllPoints()
    local x, y = GetCursorPosition()
    local scale = menu:GetEffectiveScale()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 2, y / scale - 2)
    menu:Show()
    return menu
end
