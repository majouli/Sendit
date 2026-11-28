--[[
  Overlay ("Show on screen"): outlines every visible element by state (green faded, red excluded, grey
  always visible); hover names it, a click opens the Elements page on it. Boxes wrap what an element
  draws (union of visible regions); secrets fall back to the frame. A tolerance hides boxes above a
  share of the screen; small boxes above large ones. Fading pauses while shown; Escape closes it.
]]
local _, ns = ...

local Overlay = {}
ns.Overlay = Overlay

local T, W, Safe = ns.Theme, ns.Widgets, ns.Safe

local MIN_SIZE = 4       -- px; smaller content is skipped
local MIN_ALPHA = 0.05   -- elements their owner made transparent are skipped
local MAX_WALK = 250     -- frames inspected per element for its content
local REFRESH = 2        -- seconds between content/position updates

local frame, banner
local boxes = {}
local candidates = {}  -- { e, l, b, w, h, area }

-- colour role, edge alpha, fill alpha (hover adds HOVER_FILL)
local STYLE = {
    included = { "success",   0.45, 0.06 },
    excluded = { "danger",    0.80, 0.16 },
    builtin  = { "textMuted", 0.35, 0.04 },
}
local HOVER_FILL = 0.18

local function StyleOf(e)
    local _, rule = ns.Fader:Status(e)
    if rule == nil then return STYLE.included end
    if rule == "builtin" then return STYLE.builtin end
    return STYLE.excluded
end

-- does a region draw something? nil when a secret hides the answer
local function Draws(region, alpha)
    local visible = Safe.Visibility(region)
    if visible ~= true then return visible end
    local a = Safe.Alpha(region)
    if not a then return nil end
    if a * alpha < MIN_ALPHA then return false end
    local kind = Safe.Call(region, "GetObjectType")
    if kind == "MaskTexture" then return false end
    if kind == "FontString" then
        local text = Safe.Call(region, "GetText")
        if text == nil then return nil end
        return type(text) == "string" and text ~= ""
    end
    return true
end

local function Clamp(minL, minB, maxR, maxT)
    minL, minB = math.max(0, minL), math.max(0, minB)
    maxR, maxT = math.min(UIParent:GetWidth(), maxR), math.min(UIParent:GetHeight(), maxT)
    if maxR <= minL or maxT <= minB then return nil end
    return minL, minB, maxR - minL, maxT - minB
end

-- union of drawn regions (alpha multiplied down the chain); unknown = a secret hid some part
local function ContentRect(root, rootAlpha)
    local minL, minB, maxR, maxT
    local unknown = false
    local queue, alphas, head = { root }, { rootAlpha }, 1
    while queue[head] and head <= MAX_WALK do
        local f, alpha = queue[head], alphas[head]
        head = head + 1
        local visible = Safe.Visibility(f)
        if visible == nil then unknown = true end
        if alpha >= MIN_ALPHA and not Safe.IsForbidden(f) and visible then
            for _, region in ipairs(Safe.Regions(f)) do
                local draws = Draws(region, alpha)
                if draws == nil then unknown = true end
                if draws then
                    local l, b, w, h = Safe.Rect(region)
                    if not l then unknown = true end
                    if l and w > 1 and h > 1 then
                        minL = minL and math.min(minL, l) or l
                        minB = minB and math.min(minB, b) or b
                        maxR = maxR and math.max(maxR, l + w) or l + w
                        maxT = maxT and math.max(maxT, b + h) or b + h
                    end
                end
            end
            if #queue < MAX_WALK then
                for _, child in ipairs(Safe.Children(f)) do
                    queue[#queue + 1] = child
                    alphas[#alphas + 1] = alpha * (Safe.Alpha(child) or 1)
                end
            end
        end
    end
    if not minL then return nil, nil, nil, nil, unknown end
    local l, b, w, h = Clamp(minL, minB, maxR, maxT)
    return l, b, w, h, unknown
end

local function FrameRect(f)
    local l, b, w, h = Safe.Rect(f)
    if not l then return nil end
    return Clamp(l, b, l + w, b + h)
end

local unplaced = 0  -- elements with content but no readable position

local function Collect()
    wipe(candidates)
    unplaced = 0
    local r = ns.Scanner.last
    if not r then return end
    for _, e in ipairs(r.elements) do
        local f = e.frame
        local alpha = ns.Fader:IntrinsicAlpha(f) or 1
        if alpha >= MIN_ALPHA and Safe.Visibility(f) ~= false then
            local l, b, w, h, unknown = ContentRect(f, alpha)
            if not l and unknown then
                l, b, w, h = FrameRect(f)
                if not l then unplaced = unplaced + 1 end
            end
            if l and w >= MIN_SIZE and h >= MIN_SIZE then
                candidates[#candidates + 1] = { e = e, l = l, b = b, w = w, h = h, area = w * h }
            end
        end
    end
    -- large first: smaller boxes get higher levels
    table.sort(candidates, function(a, b) return a.area > b.area end)
end

local function BoxEnter(self)
    T.Alpha(self.fill, self.style[3] + HOVER_FILL)
    self.tag:Show()
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(self.e.label, 1, 1, 1)
    local r, g, b = T.Color("textDim")
    GameTooltip:AddLine(self.e.owner .. "  -  " .. ns.Fader:Status(self.e), r, g, b)
    r, g, b = T.Color("textMuted")
    GameTooltip:AddLine(ns.L.OV_CLICK, r, g, b)
    GameTooltip:Show()
end

local function BoxLeave(self)
    T.Alpha(self.fill, self.style[3])
    self.tag:Hide()
    GameTooltip:Hide()
end

local function BoxClick(self)
    local e = self.e
    Overlay:Hide()
    ns.RevealElement(e)
end

local function CreateBox()
    local b = CreateFrame("Button", nil, frame)
    b.fill = T.Fill(b, "success", "BACKGROUND")
    b.fill:SetAllPoints()
    b.edges = T.Border(b, "success")
    b.tag = CreateFrame("Frame", nil, b)
    b.tag:SetHeight(18)
    b.tag:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 1)
    b.tagBg = T.Fill(b.tag, "panel", "BACKGROUND", 0, 0.92)
    b.tagBg:SetAllPoints()
    b.tagText = T.Text(b.tag, "small", "text")
    T.NoShadow(b.tagText)
    b.tagText:SetPoint("LEFT", 5, 0)
    b.tag:Hide()
    b:SetScript("OnEnter", BoxEnter)
    b:SetScript("OnLeave", BoxLeave)
    b:SetScript("OnClick", BoxClick)
    return b
end

local function Paint(b, c)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", c.l, c.b)
    b:SetSize(c.w, c.h)
    local style = StyleOf(c.e)
    b.style = style
    T.Paint(b.fill, style[1], style[3])
    for _, edge in ipairs(b.edges) do T.Paint(edge, style[1], style[2]) end
    b.tagText:SetText(c.e.label)
    b.tag:SetWidth(b.tagText:GetStringWidth() + 10)
    b.e = c.e
end

-- an error must not repeat every refresh: close and report once
local function SafeCollect()
    local ok, err = pcall(Collect)
    if not ok then
        Overlay:Hide()
        ns.Print("|cffff5555" .. ns.L.OVERLAY_OFF .. "|r " .. tostring(err))
    end
    return ok
end

local function Place()
    local screen = UIParent:GetWidth() * UIParent:GetHeight()
    local maxArea = ns.db.overlay.maxSize * screen
    local base = frame:GetFrameLevel() + 1
    local n, skipped = 0, 0
    for _, c in ipairs(candidates) do
        if c.area <= maxArea then
            n = n + 1
            local b = boxes[n] or CreateBox()
            boxes[n] = b
            Paint(b, c)
            b:SetFrameLevel(base + n)
            b:Show()
        else
            skipped = skipped + 1
        end
    end
    for i = n + 1, #boxes do boxes[i]:Hide() end
    banner:SetFrameLevel(base + n + 10)
    local text = ns.L.OV_SHOWN:format(n)
    if skipped > 0 then text = text .. ns.L.OV_SKIPPED:format(skipped) end
    if unplaced > 0 then text = text .. ns.L.OV_UNPLACED:format(unplaced) end
    banner.count:SetText(text)
end

local function Legend(parent, anchor, color, text)
    local dot = T.Fill(parent, color, "ARTWORK")
    dot:SetSize(10, 10)
    dot:SetPoint("LEFT", anchor, "RIGHT", 16, 0)
    local label = T.Text(parent, "small", "textDim")
    label:SetPoint("LEFT", dot, "RIGHT", 6, 0)
    label:SetText(text)
    return label
end

local function Build()
    frame = CreateFrame("Frame", "SenditFadeOverlay", UIParent)
    ns.ownFrames[frame] = true
    tinsert(UISpecialFrames, "SenditFadeOverlay")  -- Escape closes it
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()

    banner = CreateFrame("Frame", nil, frame)
    banner:SetSize(720, 84)
    W.Movable(banner, banner, { store = ns.db.overlay, key = "point", default = { "TOP", "TOP", 0, -24 } })
    T.Fill(banner, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(banner, "border")

    local title = T.Text(banner, "heading", "text")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.L.OV_TITLE)
    banner:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(ns.L.OV_DRAG, T.Color("text"))
        GameTooltip:Show()
    end)
    banner:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local last = Legend(banner, title, "success", ns.L.ST_FADED)
    last = Legend(banner, last, "danger", ns.L.R_EXCLUDED)
    Legend(banner, last, "textMuted", ns.L.LOCK_builtin)
    local done = W.Button(banner, ns.L.OV_DONE, function() Overlay:Hide() end, "primary")
    done:SetPoint("TOPRIGHT", -10, -10)

    local tolLabel = T.Text(banner, "label", "textDim")
    tolLabel:SetPoint("BOTTOMLEFT", 16, 18)
    tolLabel:SetText(ns.L.OV_LARGER)
    local slider = W.Slider(banner, 0.05, 1, 0.05,
        function() return ns.db.overlay.maxSize end,
        function(v) ns.db.overlay.maxSize = v; Place() end,
        function(v) return math.floor(v * 100 + 0.5) .. "%" end, 200)
    slider:SetPoint("LEFT", tolLabel, "RIGHT", 64, 0)
    local suffix = T.Text(banner, "label", "textMuted")
    suffix:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    suffix:SetText(ns.L.OV_SCREEN)
    banner.slider = slider

    banner.count = T.Text(banner, "small", "textMuted")
    banner.count:SetPoint("BOTTOMRIGHT", -16, 20)
    banner.count:SetJustifyH("RIGHT")

    local acc = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < REFRESH then return end
        acc = 0
        if SafeCollect() then Place() end
    end)
    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
        ns.Triggers:Hold("overlay", nil)
    end)
end

function Overlay:Show()
    if not frame then Build() end
    ns.Options:Hide()
    ns.Highlight:Hide()
    ns.Triggers:Hold("overlay", "show on screen")
    banner.slider:Refresh()
    if not SafeCollect() then
        ns.Triggers:Hold("overlay", nil)
        return
    end
    Place()
    frame:Show()
    T.FadeIn(banner, 0.25, 12)
end

function Overlay:Hide()
    if frame then frame:Hide() end
end

function Overlay:Toggle()
    if frame and frame:IsShown() then self:Hide() else self:Show() end
end
