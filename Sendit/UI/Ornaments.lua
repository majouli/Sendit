--[[
  Ornaments: the azeroth frame style - Theme.Decorate(frame, kind, opts) adds the game's gold border
  ("window", "panel") or dialog border ("dialog": banner, seal) while profile.design.style is "azeroth";
  Theme.DecoEdge(frame, px) sets the edge width. Only textures the client already ships.
]]
local _, ns = ...
local Theme = ns.Theme

local TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local DIALOG_EDGE = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_BANNER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local SEAL_RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local decorated = setmetatable({}, { __mode = "k" })

-- the gold edge at d.edgeSize; the frame line sits a fifth of it outside
local function SetEdge(d)
    local out = math.floor(d.edgeSize * 0.22 + 0.5)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", -out, out)
    d:SetPoint("BOTTOMRIGHT", out, -out)
    if not d.SetBackdrop then return end
    d:SetBackdrop({
        edgeFile = d.edgeFile,
        edgeSize = d.edgeSize,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local r, g, b = Theme.Color(d.edgeRole)
    d:SetBackdropBorderColor(r, g, b, 1)
end

local function ApplyDeco(frame)
    local d = frame.senditDeco
    local on = Theme.Style() == "azeroth"
    d:SetShown(on and d.edgeSize > 0)
    if d.banner then d.banner:SetShown(on) end
    if d.seal then d.seal:SetShown(on) end
    if on and d.SetBackdropBorderColor then
        local r, g, b = Theme.Color(d.edgeRole)
        d:SetBackdropBorderColor(r, g, b, 1)
    end
    if d.onApply then d.onApply(frame, on) end
end

-- a module's border setting: 0 hides the gold edge, else its width (default 14 / 26)
function Theme.DecoEdge(frame, size)
    local d = frame.senditDeco
    if not d or d.edgeSize == size then return end
    d.edgeSize = size
    if size > 0 then SetEdge(d) end
    d:SetShown(Theme.Style() == "azeroth" and size > 0)
end

local function ApplyAllDeco()
    for frame in pairs(decorated) do ApplyDeco(frame) end
end

-- opts: level, title, icon, edge (colour role), banner (FontString maker), onApply(frame, on)
function Theme.Decorate(frame, kind, opts)
    opts = opts or {}
    local d = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    local dialog = kind == "dialog"
    d:SetFrameLevel(frame:GetFrameLevel() + (opts.level or 1))
    d.edgeFile = dialog and DIALOG_EDGE or TOOLTIP_EDGE
    d.edgeSize = dialog and 26 or 14
    d.edgeRole = opts.edge or "edge"
    SetEdge(d)
    d.onApply = opts.onApply
    frame.senditDeco = d

    if dialog and opts.title then
        local banner = CreateFrame("Frame", nil, frame)
        banner:SetSize(260, 56)
        banner:SetPoint("TOP", frame, "TOP", 0, 22)
        banner:SetFrameLevel(d:GetFrameLevel() + 2)
        local tex = banner:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(DIALOG_BANNER)
        tex:SetAllPoints()
        banner.text = opts.banner and opts.banner(banner) or Theme.Text(banner, "heading", "accent")
        banner.text:SetPoint("TOP", 0, -14)
        banner.text:SetJustifyH("CENTER")
        banner.text:SetText(opts.title)
        d.banner = banner
    end
    if dialog and opts.icon then
        local seal = CreateFrame("Frame", nil, frame)
        seal:SetSize(53, 53)
        seal:SetPoint("TOPLEFT", frame, "TOPLEFT", -22, 22)
        seal:SetFrameLevel(d:GetFrameLevel() + 3)
        local ground = seal:CreateTexture(nil, "BACKGROUND")
        ground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        ground:SetSize(22, 22)
        ground:SetPoint("TOPLEFT", 6, -5)
        local icon = seal:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(opts.icon)
        icon:SetSize(19, 19)
        icon:SetPoint("TOPLEFT", 7, -6)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local ring = seal:CreateTexture(nil, "OVERLAY")
        ring:SetTexture(SEAL_RING)
        ring:SetSize(53, 53)
        ring:SetPoint("TOPLEFT")
        d.seal = seal
    end
    decorated[frame] = true
    ApplyDeco(frame)
    return d
end

-- after the Theme's own handler: the palette is set first
ns.OnSettingsChanged(ApplyAllDeco)
