--[[
  Layout: a settings page as sections of rows (label and description left, control right), notes and
  free blocks. Texts may be functions (resolved again on Refresh). Hovering a row with a description
  shows it whole in a tooltip (the row cuts it to one line).
  W.Layout(content) -> Lay;  Lay:Section(title) / EndSection() / Row(label, desc, control, descGap)
  Lay:Note(text) / Place(frame, height) / Refresh() / Reveal(row);  Lay.entries (for the search)
]]
local _, ns = ...

local W = ns.Widgets
local T = ns.Theme
local SIZE = T.SIZE

local Layout = {}
Layout.__index = Layout

local Resolve = ns.Locale.Resolve

function W.Layout(content)
    return setmetatable({ content = content, y = 0, controls = {}, texts = {}, entries = {} }, Layout)
end

local function Text(layout, fs, text, upper)
    if type(text) == "function" then layout.texts[#layout.texts + 1] = { fs, text, upper } end
    local v = Resolve(text) or ""
    fs:SetText(upper and v:upper() or v)
end

function Layout:Section(title)
    local h = T.Text(self.content, "heading", "textMuted")
    h:SetPoint("TOPLEFT", 0, -self.y)
    Text(self, h, title, true)
    self.y = self.y + 22
    local panel = CreateFrame("Frame", nil, self.content)
    panel:SetPoint("TOPLEFT", 0, -self.y)
    panel:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
    T.Fill(panel, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(panel, "border")
    panel.heading = h
    self.panel, self.panelRows = panel, 0
    self.section = title
    return panel
end

function Layout:Row(label, desc, control, descGap)
    local panel = self.panel
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(SIZE.row)
    row:SetPoint("TOPLEFT", 0, -self.panelRows * SIZE.row)
    row:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    if self.panelRows > 0 then
        local d = T.Fill(row, "divider", "BORDER")
        d:SetHeight(1)
        d:SetPoint("TOPLEFT", 16, 0)
        d:SetPoint("TOPRIGHT", -16, 0)
    end
    row.label = T.Text(row, "body", "text")
    row.desc = T.Text(row, "note", "textMuted")
    if desc then
        row.label:SetPoint("TOPLEFT", 16, -10)
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        Text(self, row.desc, desc)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 12, 0)
            GameTooltip:SetText(Resolve(label) or "", T.Color("text"))
            local r, g, b = T.Color("textDim")
            GameTooltip:AddLine(Resolve(desc) or "", r, g, b, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        row.label:SetPoint("LEFT", 16, 0)
    end
    Text(self, row.label, label)
    control:SetParent(row)
    control:ClearAllPoints()
    control:SetPoint("RIGHT", row, "RIGHT", -16, 0)
    row.desc:SetPoint("RIGHT", control, "LEFT", -(descGap or 24), 0)

    row.top = self.y + self.panelRows * SIZE.row  -- offset in the content (Reveal)
    self.panelRows = self.panelRows + 1
    panel:SetHeight(self.panelRows * SIZE.row)
    self.controls[#self.controls + 1] = control
    self.entries[#self.entries + 1] = { section = self.section, label = label, desc = desc, row = row }
    return row
end

function Layout:EndSection()
    self.y = self.y + self.panelRows * SIZE.row + 24
    self.content:SetHeight(self.y)
end

function Layout:Note(text)
    local fs = T.Text(self.content, "note", "textMuted")
    fs:SetPoint("TOPLEFT", 0, -self.y)
    Text(self, fs, text)
    self.y = self.y + 20
    self.content:SetHeight(self.y)
    return fs
end

function Layout:Place(frame, height)
    frame:SetParent(self.content)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 0, -self.y)
    frame:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
    frame:SetHeight(height)
    if type(frame.Refresh) == "function" then self.controls[#self.controls + 1] = frame end
    self.y = self.y + height + 12
    self.content:SetHeight(self.y)
    return frame
end

-- the search's jump target: scroll near the top, then a fading wash
local FLASH_HOLD, FLASH_FADE = 0.5, 1.2

function Layout:Reveal(row)
    local sf = self.content:GetParent()
    if sf and sf.SetVerticalScroll then
        local max = math.max(0, self.content:GetHeight() - (sf:GetHeight() or 0))
        sf:SetVerticalScroll(math.min(max, math.max(0, (row.top or 0) - 40)))
    end
    if not row.flash then
        row.flash = CreateFrame("Frame", nil, row)
        row.flash:SetAllPoints()
        T.Fill(row.flash, "accent", "BACKGROUND", 1, 0.18):SetAllPoints()
        local fade = row.flash:CreateAnimationGroup()
        local a = fade:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0)
        a:SetDuration(FLASH_FADE)
        a:SetStartDelay(FLASH_HOLD)
        row.flash.fade = fade
    end
    local flash = row.flash
    local token = {}
    flash.token = token
    flash.fade:Stop()
    flash:Show()
    flash.fade:Play()
    C_Timer.After(FLASH_HOLD + FLASH_FADE, function()
        if flash.token == token then flash:Hide() end
    end)
end

function Layout:Refresh()
    for _, t in ipairs(self.texts) do
        local v = Resolve(t[2]) or ""
        t[1]:SetText(t[3] and v:upper() or v)
    end
    for _, c in ipairs(self.controls) do c:Refresh() end
end
