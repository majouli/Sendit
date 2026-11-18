--[[
  Theme: palettes, fonts and paint helpers shared by every Sendit module.
  Modules paint through Sendit.Theme, so the design picked in the profile
  (Design page) repaints all of them live.

  Design language after Polestar's house style: a night ground, a text
  ladder (100 / ~77 / ~61 %), 1px hairlines as low-alpha "ink" washes, one
  accent, the game's own font. Own code, no Polestar code or media.

  Palettes: dusk (default, Polestar's navy), light, wood (dark wood brown,
  WoW gold). Each palette carries a chat sub-palette (roles "chat.<name>",
  Sendit_Chat): dusk and light share the dark modern chat (Blizzard's white
  and yellow chat text needs a dark ground), wood has the azeroth chat.

  Frame style (profile.design.style): "modern" hairlines or "azeroth"
  ornaments (Theme.Decorate, UI/Ornaments.lua). Fonts for every alphabet:
  Theme.SetFont (UI/Fonts.lua).

  Every painted texture/text remembers its colour role and alpha, so a
  palette switch repaints the whole UI live (Theme.SetPalette).
  Never call SetAlpha on a painted texture: in this client it shares the
  value with SetVertexColor's alpha, and the next repaint would undo it.
  Use Theme.Paint(obj, role, alpha) / Theme.Alpha(obj, alpha) instead.
]]
local _, ns = ...

-- The design section of the active profile (nil until the saved variables load).
local function Design() return ns.profile and ns.profile.design end

local Theme = {}
ns.Theme = Theme

local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
Theme.WHITE = WHITE

---------------------------------------------------------------------------
-- Palettes
---------------------------------------------------------------------------
-- Washes: ink colour at these alphas (white ink on dark grounds, black on light).
local WASH = { border = 0.10, divider = 0.10, hover = 0.07, selected = 0.12, track = 0.12, toggle = 0.14, box = 0.22 }
local LIGHT_WASH = { border = 0.12, divider = 0.10, hover = 0.05, selected = 0.08, track = 0.12, toggle = 0.18, box = 0.30 }

local PALETTES = {
    dusk = {
        name = "Dusk",
        bg = { 0.095, 0.115, 0.178, 0.97 }, panel = { 0.110, 0.133, 0.203, 0.98 },
        panelAlt = { 0.139, 0.166, 0.249, 1 }, sidebar = { 0.072, 0.088, 0.140, 1 },
        footer = { 0.080, 0.097, 0.151, 1 }, sky = { 0.156, 0.196, 0.329, 1 },
        text = { 0.967, 0.974, 0.991, 1 }, textDim = { 0.765, 0.793, 0.868, 1 }, textMuted = { 0.606, 0.637, 0.726, 1 },
        accent = { 0.900, 0.730, 0.400, 1 }, onAccent = { 0.040, 0.050, 0.080, 1 },
        success = { 0.420, 0.850, 0.600, 1 }, warning = { 0.980, 0.750, 0.300, 1 }, danger = { 0.960, 0.450, 0.450, 1 },
        star = { 1, 1, 1, 1 }, shadow = { 0, 0, 0.02, 0.6 }, textShadow = 0.6,
        ink = { 1, 1, 1 }, wash = WASH,
    },
    light = {
        name = "Light",
        bg = { 0.965, 0.965, 0.975, 0.98 }, panel = { 1, 1, 1, 1 },
        panelAlt = { 0.925, 0.932, 0.950, 1 }, sidebar = { 0.925, 0.930, 0.945, 1 },
        footer = { 0.940, 0.944, 0.958, 1 }, sky = { 0.835, 0.870, 0.960, 1 },
        text = { 0.090, 0.100, 0.130, 1 }, textDim = { 0.300, 0.320, 0.380, 1 }, textMuted = { 0.460, 0.480, 0.540, 1 },
        accent = { 0.780, 0.540, 0.100, 1 }, onAccent = { 1, 1, 1, 1 },
        success = { 0.120, 0.560, 0.330, 1 }, warning = { 0.820, 0.450, 0.050, 1 }, danger = { 0.800, 0.200, 0.200, 1 },
        star = { 0.780, 0.540, 0.100, 1 }, shadow = { 0, 0, 0, 0.25 }, textShadow = 0,
        ink = { 0, 0, 0 }, wash = LIGHT_WASH,
    },
    wood = {
        name = "Wood",
        bg = { 0.130, 0.090, 0.060, 0.97 }, panel = { 0.170, 0.120, 0.080, 0.98 },
        panelAlt = { 0.220, 0.160, 0.100, 1 }, sidebar = { 0.100, 0.068, 0.045, 1 },
        footer = { 0.110, 0.076, 0.050, 1 }, sky = { 0.300, 0.190, 0.100, 1 },
        text = { 0.980, 0.940, 0.860, 1 }, textDim = { 0.850, 0.780, 0.660, 1 }, textMuted = { 0.660, 0.580, 0.470, 1 },
        accent = { 1.000, 0.820, 0.000, 1 }, onAccent = { 0.120, 0.080, 0.030, 1 },
        success = { 0.550, 0.850, 0.400, 1 }, warning = { 1.000, 0.600, 0.240, 1 }, danger = { 0.950, 0.400, 0.330, 1 },
        star = { 1, 0.9, 0.6, 1 }, shadow = { 0, 0, 0, 0.7 }, textShadow = 0.8,
        ink = { 1, 0.92, 0.75 }, wash = WASH,
    },
}
-- Chat colours (Sendit_Chat's own roles).
local MODERN_CHAT = {
    bg = { 0.060, 0.072, 0.112 }, header = { 0.085, 0.102, 0.158 }, raised = { 0.120, 0.143, 0.215 },
    text = { 0.967, 0.974, 0.991 }, textDim = { 0.765, 0.793, 0.868 }, textMuted = { 0.606, 0.637, 0.726 },
    accent = { 0.900, 0.730, 0.400 }, onAccent = { 0.040, 0.050, 0.080 }, ink = { 1, 1, 1 },
    danger = { 0.960, 0.450, 0.450 },
    bubbleIn = { 0.150, 0.175, 0.255 }, bubbleOut = { 0.330, 0.270, 0.150 },
    bn = { 0.000, 0.800, 1.000 }, bubbleBN = { 0.090, 0.200, 0.290 },
    edge = { 1, 1, 1 },
}
local AZEROTH_CHAT = {
    bg = { 0.075, 0.055, 0.035 }, header = { 0.150, 0.100, 0.050 }, raised = { 0.230, 0.160, 0.085 },
    text = { 1.000, 0.960, 0.860 }, textDim = { 0.880, 0.800, 0.640 }, textMuted = { 0.690, 0.600, 0.460 },
    accent = { 1.000, 0.820, 0.000 }, onAccent = { 0.120, 0.080, 0.020 }, ink = { 1.000, 0.900, 0.700 },
    danger = { 1.000, 0.380, 0.300 },
    bubbleIn = { 0.200, 0.145, 0.085 }, bubbleOut = { 0.360, 0.270, 0.080 },
    bn = { 0.000, 0.800, 1.000 }, bubbleBN = { 0.070, 0.170, 0.240 },
    edge = { 1.000, 0.820, 0.300 },
}
PALETTES.dusk.chat, PALETTES.light.chat, PALETTES.wood.chat = MODERN_CHAT, MODERN_CHAT, AZEROTH_CHAT
PALETTES.dusk.edge, PALETTES.light.edge, PALETTES.wood.edge = { 0.900, 0.730, 0.400 }, { 0.780, 0.540, 0.100 }, { 1.000, 0.820, 0.300 }

Theme.PALETTE_ORDER = { "dusk", "light", "wood" }
Theme.PALETTES = PALETTES

local C  -- the active palette

Theme.SIZE = {
    width = 860, height = 600, sidebar = 220, header = 96, footer = 52, pad = 28, row = 52,
}

---------------------------------------------------------------------------
-- Colour lookup and live repaint
---------------------------------------------------------------------------
local painted = setmetatable({}, { __mode = "k" })    -- object -> role
local alphas = setmetatable({}, { __mode = "k" })     -- object -> alpha multiplier
local byRole = {}                                     -- role -> weak set
local gradients = setmetatable({}, { __mode = "k" })  -- texture -> { top, bottom }
local noShadow = setmetatable({}, { __mode = "k" })   -- font strings without shadow

function Theme.Color(name)
    local chatRole = name:match("^chat%.(.+)$")
    if chatRole then
        local cc = C.chat[chatRole] or C.chat.text
        return cc[1], cc[2], cc[3], cc[4] or 1
    end
    local c = C[name]
    if not c then
        local a = C.wash[name]
        if a then return C.ink[1], C.ink[2], C.ink[3], a end
        c = C.text
    end
    return c[1], c[2], c[3], c[4] or 1
end

local function Apply(obj, role)
    local r, g, b, a = Theme.Color(role)
    a = a * (alphas[obj] or 1)
    local t = obj:GetObjectType()
    if t == "FontString" or t == "EditBox" then
        obj:SetTextColor(r, g, b, a)
        if t == "FontString" then
            obj:SetShadowColor(0, 0, 0, noShadow[obj] and 0 or C.textShadow)
        end
    else
        obj:SetVertexColor(r, g, b, a)
    end
end

-- Paint (and remember) an object's colour role, optionally with an alpha.
function Theme.Paint(obj, role, alpha)
    local old = painted[obj]
    if old ~= role then
        if old and byRole[old] then byRole[old][obj] = nil end
        painted[obj] = role
        byRole[role] = byRole[role] or setmetatable({}, { __mode = "k" })
        byRole[role][obj] = true
    end
    if alpha then alphas[obj] = alpha end
    Apply(obj, role)
end

-- The caller colours obj itself from now on (repaints leave it alone).
function Theme.Own(obj)
    local role = painted[obj]
    if role and byRole[role] then byRole[role][obj] = nil end
    painted[obj], alphas[obj] = nil, nil
end

-- Change only the alpha of a painted object.
function Theme.Alpha(obj, alpha)
    alphas[obj] = alpha
    if painted[obj] then Apply(obj, painted[obj]) end
end

function Theme.NoShadow(fs)
    noShadow[fs] = true
    fs:SetShadowColor(0, 0, 0, 0)
end

local function ApplyGradient(tex, top, bottom)
    local r1, g1, b1, a1 = Theme.Color(bottom)
    local r2, g2, b2, a2 = Theme.Color(top)
    tex:SetVertexColor(1, 1, 1, 1)
    local ok = CreateColor and pcall(tex.SetGradient, tex, "VERTICAL",
        CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    if not ok then tex:SetVertexColor(r2, g2, b2, a2) end
end

function Theme.Gradient(tex, top, bottom)
    gradients[tex] = { top, bottom }
    ApplyGradient(tex, top, bottom)
end

local function RepaintAll()
    for obj, role in pairs(painted) do Apply(obj, role) end
    for tex, g in pairs(gradients) do ApplyGradient(tex, g[1], g[2]) end
end

---------------------------------------------------------------------------
-- Palette switching
---------------------------------------------------------------------------
function Theme.PaletteKey()
    local d = Design()
    return d and PALETTES[d.palette] and d.palette or "dusk"
end

-- The active palette table (read-only for callers).
function Theme.Current() return C end

function Theme.Style()
    local d = Design()
    return d and d.style == "azeroth" and "azeroth" or "modern"
end

function Theme.SetPalette(key)
    local src = PALETTES[key] or PALETTES.dusk
    C = src
    RepaintAll()
end

Theme.SetPalette("dusk")  -- until the saved variables are loaded

local applied = "dusk"
ns.OnSettingsChanged(function()
    local key = Theme.PaletteKey()
    if key ~= applied then
        applied = key
        Theme.SetPalette(key)
    end
end)

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------
-- Text roles: size, heavier (stronger shadow). The game font has one weight.
local ROLES = {
    hero    = 24, title = 17, heading = 13, body = 13,
    label   = 12, note = 12, small = 11, caption = 10,
}

Theme.SetFont = ns.Fonts.Set

function Theme.Text(parent, role, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    Theme.SetFont(fs, ROLES[role] or ROLES.body)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    Theme.Paint(fs, color or "text")
    return fs
end

function Theme.Fill(parent, color, layer, sub, alpha)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(WHITE)
    Theme.Paint(t, color, alpha)
    return t
end

-- 1px hairline border around a frame.
function Theme.Border(frame, color)
    local edges = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                          { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = Theme.Fill(frame, color or "border", "BORDER")
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        edges[i] = t
    end
    return edges
end

-- Clip a texture to a circle.
function Theme.RoundOff(tex)
    local mask = tex:GetParent():CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return tex
end

-- A filled circle, e.g. switch knobs and pill caps.
function Theme.Circle(parent, color, size, layer, sub)
    local t = Theme.Fill(parent, color, layer or "ARTWORK", sub)
    t:SetSize(size, size)
    return Theme.RoundOff(t)
end

-- Pill shape (rect + two round caps), painted as one.
function Theme.Pill(parent, color, w, h, layer, sub)
    local left = Theme.Circle(parent, color, h, layer, sub)
    local right = Theme.Circle(parent, color, h, layer, sub)
    local mid = Theme.Fill(parent, color, layer or "ARTWORK", sub)
    mid:SetPoint("TOPLEFT", left, "TOP")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOM")
    local p = { parts = { left, right, mid } }
    function p:SetPoint(...)
        left:SetPoint(...)
        right:SetPoint("LEFT", left, "LEFT", w - h, 0)
    end
    function p:Paint(c, alpha) for _, t in ipairs(self.parts) do Theme.Paint(t, c, alpha) end end
    return p
end

---------------------------------------------------------------------------
-- Motion (skipped when animations are off)
---------------------------------------------------------------------------
local function Animated()
    return not Design() or Design().animations
end

-- Fade a frame in, optionally rising `rise` px into place.
function Theme.FadeIn(frame, duration, rise)
    if not Animated() then return end
    local ag = frame.senditFadeIn
    if not ag then
        ag = frame:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0)
        a:SetToAlpha(1)
        a:SetSmoothing("OUT")
        ag.alpha = a
        if rise then
            local down = ag:CreateAnimation("Translation")
            down:SetOffset(0, -rise)
            down:SetDuration(0)
            down:SetOrder(1)
            local up = ag:CreateAnimation("Translation")
            up:SetOffset(0, rise)
            up:SetSmoothing("OUT")
            up:SetOrder(2)
            ag.up = up
            a:SetOrder(2)
        end
        frame.senditFadeIn = ag
    end
    ag.alpha:SetDuration(duration or 0.18)
    if ag.up then ag.up:SetDuration(duration or 0.18) end
    ag:Stop()
    ag:Play()
end

-- Slow random twinkle on a texture (header stars), from its painted alpha.
function Theme.Twinkle(tex, seed)
    local base = alphas[tex] or 1
    local ag = tex:GetParent():CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetTarget(tex)
    a:SetFromAlpha(base)
    a:SetToAlpha(base * 0.2)
    a:SetDuration(1.5 + (seed % 25) / 10)
    a:SetSmoothing("IN_OUT")
    tex.senditTwinkle = ag
    return ag
end
