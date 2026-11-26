--[[
  Nav: the scrolling list in the Sendit window's sidebar - rows (modules, their pages, windows, core
  pages) and section captions between the fixed brand/search on top and the version below. The wheel
  scrolls smoothly (offset eased per frame, at once without animations); a thin bar shows where the view
  is and a chevron that there is more; the focused row is scrolled into view.
  Nav.Create(side, top, bottomGap) -> list;  list.content = the parent of rows and captions
  list:Place(entries, focus): entries = { frame, height, indent? } top to bottom, focus = a row to show
  Nav.Row(parent, text, icon, sub, onClick) -> row (row:SetSelected(on, strong), row:SetOpen(open, expandable):
    the chevron of a module that opens; row.dim, row.switch). A sub row's icon is small (a window).
  Nav.Caption(parent, text) -> caption (a frame CAPTION high; text may be a function)
]]
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local Resolve = ns.Locale.Resolve
local SIZE = T.SIZE

local Nav = {}
ns.Nav = Nav

Nav.ROW, Nav.SUB, Nav.CAPTION = 32, 26, 30
local WHEEL, EASE, BAR_W, THUMB_MIN = 48, 14, 2, 24

function Nav.Row(parent, text, icon, sub, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIZE.sidebar, sub and Nav.SUB or Nav.ROW)
    b.sel = T.Fill(b, sub and "hover" or "selected", "BACKGROUND")
    b.sel:SetAllPoints()
    b.bar = T.Fill(b, "accent", "ARTWORK")
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(2)
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    local x = sub and 48 or 20
    if icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture(icon)
        b.icon:SetSize(sub and 14 or 20, sub and 14 or 20)
        b.icon:SetPoint("LEFT", sub and 28 or 18, 0)
        x = 48
    end
    b.text = T.Text(b, sub and "label" or "body", "textDim")
    b.text:SetPoint("LEFT", x, 0)
    b.text:SetPoint("RIGHT", sub and -16 or -64, 0)  -- room for the chevron and a module switch
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.textSource = text
    b.text:SetText(Resolve(text) or "")
    if not sub then
        b.chevron = W.Chevron(b, "textMuted", "right")
        b.chevron:SetPoint("RIGHT", -50, 0)
        b.chevron:Hide()
    end
    function b:SetSelected(on, strong)
        self.text:SetText(Resolve(self.textSource) or "")
        self.sel:SetShown(on)
        self.bar:SetShown(on and strong ~= false)
        T.Paint(self.text, on and "text" or (self.dim and "textMuted" or "textDim"))
        if self.icon then self.icon:SetDesaturated(self.dim == true) end
        if self.switch then self.switch:Refresh() end
    end
    function b:SetOpen(open, expandable)
        if not self.chevron then return end
        self.chevron:SetShown(expandable == true)
        self.chevron:Point(open and "down" or "right")
    end
    b:SetScript("OnClick", onClick)
    return b
end

function Nav.Caption(parent, text)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(SIZE.sidebar, Nav.CAPTION)
    c.text = T.Text(c, "caption", "accent")
    c.text:SetPoint("BOTTOMLEFT", 20, 7)
    c.source = text
    function c:Refresh() self.text:SetText((Resolve(self.source) or ""):upper()) end
    c:Refresh()
    return c
end

function Nav.Create(side, top, bottomGap)
    local sf = CreateFrame("ScrollFrame", nil, side)
    sf:SetPoint("TOP", top, "BOTTOM", 0, -12)
    sf:SetPoint("LEFT", side, "LEFT")
    sf:SetPoint("RIGHT", side, "RIGHT", -1, 0)
    sf:SetPoint("BOTTOM", side, "BOTTOM", 0, bottomGap)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(SIZE.sidebar, 1)
    sf:SetScrollChild(content)
    sf.content = content
    sf.offset, sf.target, sf.total = 0, 0, 0
    local cover = CreateFrame("Frame", nil, side)  -- above the rows: bar and chevron
    cover:SetAllPoints(sf)
    cover:SetFrameLevel(sf:GetFrameLevel() + 10)

    local hint = CreateFrame("Frame", nil, cover)
    hint:SetSize(16, 10)
    hint:SetPoint("BOTTOM", sf, "BOTTOM", 0, 2)
    W.Chevron(hint, "textMuted", "down"):SetPoint("CENTER")
    sf.more = hint

    sf.track = T.Fill(cover, "track", "OVERLAY")
    sf.track:SetWidth(BAR_W)
    sf.track:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -3, -4)
    sf.track:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", -3, 4)
    local thumb = CreateFrame("Button", nil, cover)
    thumb:SetFrameLevel(cover:GetFrameLevel() + 1)
    thumb:SetWidth(10)
    thumb.fill = T.Fill(thumb, "accent", "OVERLAY", 0, 0.55)
    thumb.fill:SetWidth(BAR_W)
    thumb.fill:SetPoint("TOPRIGHT", -3, 0)
    thumb.fill:SetPoint("BOTTOMRIGHT", -3, 0)
    sf.thumb = thumb

    local function Max() return math.max(0, sf.total - (sf:GetHeight() or 0)) end

    local function Paint()
        local view, max = sf:GetHeight() or 0, Max()
        sf:SetVerticalScroll(sf.offset)
        local scrolls = max > 0
        sf.more:SetShown(scrolls and sf.offset < max - 1)
        sf.track:SetShown(scrolls)
        thumb:SetShown(scrolls)
        if scrolls then
            local trackH = view - 8
            local h = math.max(THUMB_MIN, trackH * view / sf.total)
            thumb:SetHeight(h)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -4 - (trackH - h) * sf.offset / max)
        end
    end

    local function Step(_, elapsed)
        local d = sf.target - sf.offset
        if math.abs(d) < 0.5 then
            sf.offset = sf.target
            sf:SetScript("OnUpdate", nil)
        else
            sf.offset = sf.offset + d * math.min(1, elapsed * EASE)
        end
        Paint()
    end

    function sf:ScrollTo(y, now)
        self.target = math.max(0, math.min(Max(), y))
        if now or not T.Animated() then
            self.offset = self.target
            self:SetScript("OnUpdate", nil)
            return Paint()
        end
        self:SetScript("OnUpdate", Step)
    end

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta) self:ScrollTo(self.target - delta * WHEEL) end)
    sf:SetScript("OnSizeChanged", function(self) self:ScrollTo(self.target, true) end)

    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        local _, y = GetCursorPosition()
        self.from, self.start = y / UIParent:GetEffectiveScale(), sf.offset
        self:SetScript("OnUpdate", function()
            local _, now = GetCursorPosition()
            local view = sf:GetHeight() or 1
            local perPixel = sf.total / math.max(1, view - 8)
            sf:ScrollTo(self.start + (self.from - now / UIParent:GetEffectiveScale()) * perPixel, true)
        end)
    end)
    thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    function sf:Place(entries, focus)
        local y, focusTop, focusBottom = 0, nil, nil
        for _, e in ipairs(entries) do
            e.frame:ClearAllPoints()
            e.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            e.frame:Show()
            if e.frame == focus then focusTop, focusBottom = y, y + e.height end
            y = y + e.height
        end
        self.total = y + 8
        content:SetHeight(math.max(1, self.total))
        local view = self:GetHeight() or 0
        local target = self.target
        if focusTop and view > 0 then
            if focusTop < target then target = focusTop - Nav.CAPTION end
            if focusBottom > target + view then target = focusBottom - view + 8 end
        end
        self:ScrollTo(target)
        Paint()
    end

    return sf
end
