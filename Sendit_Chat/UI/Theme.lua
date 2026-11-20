--[[
  Theme: the chat's drawing helpers on Sendit's theme - chat roles are the palette's "chat.<name>"
  sub-palette, ornaments are Sendit.Theme.Decorate. Theme.Color(obj, role, alpha) paints and remembers;
  Theme.Own(obj) for objects coloured by hand. Never SetAlpha a painted texture.
]]
local _, ns = ...

local Core = Sendit.Theme
local Theme = {}
ns.Theme = Theme

local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
Theme.WHITE = WHITE
Theme.FONT = STANDARD_TEXT_FONT
Theme.STYLES = { "modern", "azeroth" }
Theme.style, Theme.palette = "modern", "dusk"

Theme.C = setmetatable({}, { __index = function(_, k) return Core.Current().chat[k] end })

local iconOwners = setmetatable({}, { __mode = "k" })
local bordered = setmetatable({}, { __mode = "k" })

function Theme.RGB(name)
    local r, g, b = Core.Color("chat." .. name)
    return r, g, b
end

-- the client's chat font (roman file)
function Theme.ChatFont()
    local f = _G["ChatFontNormal"]
    local file = f and f.GetFont and f:GetFont()
    return file or STANDARD_TEXT_FONT
end

-- font for every alphabet: the chat font with ChatFontNormal's alphabets, else the UI font
function Theme.SetFont(obj, size, chat)
    if chat then
        Core.SetFont(obj, size, Theme.ChatFont(), _G["ChatFontNormal"])
    else
        Core.SetFont(obj, size, Theme.FONT)
    end
end

-- Painting with remembered roles (the core's registry)
function Theme.Color(obj, color, alpha)
    Core.Paint(obj, "chat." .. color, alpha or 1)
end

function Theme.Own(obj) Core.Own(obj) end

function Theme.Tex(parent, layer, color, alpha, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(WHITE)
    Theme.Color(t, color, alpha)
    return t
end

-- chat = the chat font, else the UI font
function Theme.Text(parent, size, color, layer, chat)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    Theme.SetFont(fs, size or 12, chat)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.6)
    fs:SetJustifyH("LEFT")
    Theme.Color(fs, color or "text")
    return fs
end

-- 1px (or px) frame line; hidden on decorated frames in the azeroth style
function Theme.Border(frame, px, color, alpha)
    local b = {
        top = Theme.Tex(frame, "BORDER", color or "ink", alpha or 0.10),
        bottom = Theme.Tex(frame, "BORDER", color or "ink", alpha or 0.10),
        left = Theme.Tex(frame, "BORDER", color or "ink", alpha or 0.10),
        right = Theme.Tex(frame, "BORDER", color or "ink", alpha or 0.10),
    }
    b.top:SetPoint("TOPLEFT"); b.top:SetPoint("TOPRIGHT")
    b.bottom:SetPoint("BOTTOMLEFT"); b.bottom:SetPoint("BOTTOMRIGHT")
    b.left:SetPoint("TOPLEFT"); b.left:SetPoint("BOTTOMLEFT")
    b.right:SetPoint("TOPRIGHT"); b.right:SetPoint("BOTTOMRIGHT")
    frame.senditBorder = b
    frame.senditBorderPx = px or 1
    bordered[frame] = true
    Theme.SetBorder(frame, px or 1)
    return b
end

-- azeroth: px sets the gold edge (1 = standard, +3 px per pixel, 0 = none)
local function EdgeSize(px) return px > 0 and 14 + (px - 1) * 3 or 0 end

function Theme.SetBorder(frame, px)
    local b = frame.senditBorder
    if not b then return end
    frame.senditBorderPx = px
    if frame.senditDeco and Core.DecoEdge then Core.DecoEdge(frame, EdgeSize(px)) end
    local show = px > 0 and not (frame.senditDeco and Core.Style() == "azeroth")
    for _, t in pairs(b) do t:SetShown(show) end
    if not show then return end
    b.top:SetHeight(px); b.bottom:SetHeight(px)
    b.left:SetWidth(px); b.right:SetWidth(px)
end

-- named only where the client needs it (UISpecialFrames)
function Theme.Panel(parent, strata, name)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:SetFrameStrata(strata or "MEDIUM")
    f:EnableMouse(true)
    f.bg = Theme.Tex(f, "BACKGROUND", "bg", 0.96)
    f.bg:SetAllPoints()
    Theme.Border(f, 1)
    f:Hide()
    return f
end

function Theme.Decorate(frame, kind, opts)
    opts = opts or {}
    return Core.Decorate(frame, kind, {
        level = opts.level, title = opts.title, icon = opts.icon, edge = "chat.edge",
        banner = function(banner) return Theme.Text(banner, 13, "accent") end,
        onApply = function(f) Theme.SetBorder(f, f.senditBorderPx or 1) end,
    })
end

-- the core repaints painted objects and ornaments; the chat redraws its icons and hairlines
function Theme.SetLook(paletteKey, style)
    Theme.palette = paletteKey
    Theme.style = style == "azeroth" and "azeroth" or "modern"
    for owner in pairs(iconOwners) do Theme.IconColor(owner, owner.senditIconRole, owner.senditIconAlpha) end
    for frame in pairs(bordered) do Theme.SetBorder(frame, frame.senditBorderPx or 1) end
end

function Theme.ClassRGB(class)
    local colors = _G["RAID_CLASS_COLORS"]
    local c = class and colors and colors[class]
    if c then return c.r, c.g, c.b end
    return Theme.RGB("text")
end

-- first character (UTF-8 aware), upper-cased when ASCII
function Theme.Initial(name)
    local ch = type(name) == "string" and name:match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
    return ch:upper()
end

-- round avatar: the initial in the class colour
function Theme.Avatar(parent, size)
    local a = CreateFrame("Frame", nil, parent)
    a:SetSize(size, size)
    a.disc = Theme.Tex(a, "ARTWORK", "raised", 1)
    a.disc:SetAllPoints()
    Theme.Own(a.disc)
    local mask = a:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    a.disc:AddMaskTexture(mask)
    a.letter = Theme.Text(a, math.floor(size * 0.45), "text")
    Theme.Own(a.letter)
    a.letter:SetPoint("CENTER", 0, 0)
    a.letter:SetJustifyH("CENTER")
    function a.Set(_, name, class)
        local r, g, b = Theme.ClassRGB(class)
        a.disc:SetVertexColor(r * 0.35, g * 0.35, b * 0.35, 1)
        a.letter:SetText(Theme.Initial(name))
        a.letter:SetTextColor(r, g, b, 1)
    end
    return a
end

local ICONS = {
    close = { { -4, 4, 4, -4 }, { -4, -4, 4, 4 } },
    minimize = { { -5, -3, 5, -3 } },
    restore = { { -5, 4, 5, 4 }, { -5, -4, 5, -4 }, { -5, 4, -5, -4 }, { 5, 4, 5, -4 } },
    plus = { { -5, 0, 5, 0 }, { 0, -5, 0, 5 } },
    settings = { { -6, 4, 6, 4 }, { -6, 0, 6, 0 }, { -6, -4, 6, -4 },
                 { 2, 6, 2, 2 }, { -3, 2, -3, -2 }, { 1, -2, 1, -6 } },
    lock = { { -5, -1, 5, -1 }, { -5, -6, 5, -6 }, { -5, -1, -5, -6 }, { 5, -1, 5, -6 },
             { -3, -1, -3, 3 }, { 3, -1, 3, 3 }, { -3, 3, -1, 5 }, { 3, 3, 1, 5 }, { -1, 5, 1, 5 } },
    unlock = { { -5, -1, 5, -1 }, { -5, -6, 5, -6 }, { -5, -1, -5, -6 }, { 5, -1, 5, -6 },
               { -3, -1, -3, 3 }, { -3, 3, -1, 5 }, { -1, 5, 1, 5 }, { 1, 5, 3, 3 } },
    messages = { { -6, 5, 6, 5 }, { -6, -2, -1, -2 }, { 2, -2, 6, -2 }, { -6, 5, -6, -2 }, { 6, 5, 6, -2 },
                 { -1, -2, -3, -6 }, { -3, -6, 2, -2 } },
    down = { { -4, 2, 0, -2 }, { 4, 2, 0, -2 } },
    -- two sheets: the back one's top and left edge, the front one whole
    copy = { { -5, 6, 3, 6 }, { -5, 6, -5, -2 },
             { -2, 3, 6, 3 }, { 6, 3, 6, -6 }, { 6, -6, -2, -6 }, { -2, -6, -2, 3 } },
    bell = { { -6, -3, 6, -3 }, { -6, -3, -4, -1 }, { 6, -3, 4, -1 }, { -4, -1, -4, 2 }, { 4, -1, 4, 2 },
             { -4, 2, -2, 5 }, { 4, 2, 2, 5 }, { -2, 5, 2, 5 }, { -1, -5, 1, -5 } },
    note = { { -4, 6, 4, 6 }, { 4, 6, 4, -6 }, { 4, -6, -4, -6 }, { -4, -6, -4, 6 },
             { -2, 3, 2, 3 }, { -2, 0, 2, 0 }, { -2, -3, 1, -3 } },
    -- two people: one in front, one behind to the right
    friends = { { -4, 4, -2, 6 }, { -2, 6, 0, 4 }, { 0, 4, -2, 2 }, { -2, 2, -4, 4 },
                { -6, -5, -6, -2 }, { -6, -2, -4, 0 }, { -4, 0, 0, 0 }, { 0, 0, 2, -2 }, { 2, -2, 2, -5 },
                { 3, 5, 5, 3 }, { 5, 3, 3, 1 }, { 3, -1, 6, -1 }, { 6, -1, 7, -3 }, { 7, -3, 7, -5 } },
}

function Theme.Icon(owner, kind, color, alpha)
    owner.senditLines = owner.senditLines or {}
    for _, l in ipairs(owner.senditLines) do l:Hide() end
    local spec = ICONS[kind] or {}
    for i, seg in ipairs(spec) do
        local l = owner.senditLines[i]
        if not l then
            l = owner:CreateLine(nil, "ARTWORK")
            l:SetThickness(1.4)
            l:SetTexture(WHITE)
            owner.senditLines[i] = l
        end
        l:SetStartPoint("CENTER", owner, seg[1], seg[2])
        l:SetEndPoint("CENTER", owner, seg[3], seg[4])
        l:Show()
    end
    owner.senditIconCount = #spec
    Theme.IconColor(owner, color or "textMuted", alpha)
end

function Theme.IconColor(owner, color, alpha)
    iconOwners[owner] = true
    owner.senditIconRole, owner.senditIconAlpha = color, alpha
    local r, g, b = Theme.RGB(color)
    for i = 1, owner.senditIconCount or 0 do
        owner.senditLines[i]:SetVertexColor(r, g, b, alpha or 1)
    end
end
