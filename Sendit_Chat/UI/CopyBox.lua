--[[
  CopyBox: a tab's or conversation's text as plain lines, selected for Ctrl+A / Ctrl+C; Escape closes it.
  Named without "chat" (Fade's chat peek leaves it alone).  CopyBox.Show(lines)
  CopyBox.Name(text): a small field at the cursor, closed by Ctrl+C (addons may not write the clipboard).
]]
local _, ns = ...
local T, Widgets, Links = ns.Theme, ns.Widgets, ns.Links
local L = ns.L

local CopyBox = {}
ns.CopyBox = CopyBox

local box

local function Build()
    box = T.Panel(UIParent, "DIALOG", "SenditCopyBox")
    box:SetSize(560, 380)
    box:SetPoint("CENTER")
    box:SetClampedToScreen(true)
    T.Decorate(box, "panel")
    box.title = T.Text(box, 13, "text")
    box.title:SetPoint("TOPLEFT", 16, -14)
    box.hint = T.Text(box, 10, "textMuted")
    box.hint:SetPoint("LEFT", box.title, "RIGHT", 12, 0)
    local close = Widgets.IconButton(box, "close", "CLOSE", function() box:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -10)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -40)
    scroll:SetPoint("BOTTOMRIGHT", -34, 14)
    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    T.SetFont(eb, 12, true)
    eb:SetWidth(500)
    eb:SetScript("OnEscapePressed", function() box:Hide() end)
    scroll:SetScrollChild(eb)
    box.eb = eb
    table.insert(UISpecialFrames, "SenditCopyBox")
end

function CopyBox.Show(lines)
    if not box then Build() end
    local out = {}
    for _, l in ipairs(lines or {}) do out[#out + 1] = Links.Plain(l[1]) end
    box.title:SetText(L.COPY_TEXT)  -- on every show: follows a language switch
    box.hint:SetText(L.COPY_HINT)
    box:Show()
    box.eb:SetText(table.concat(out, "\n"))
    box.eb:SetFocus()
    box.eb:HighlightText()
end

local mini

local function BuildMini()
    mini = T.Panel(UIParent, "TOOLTIP", "SenditCopyName")
    mini:SetClampedToScreen(true)
    T.Decorate(mini, "panel")
    local eb = CreateFrame("EditBox", nil, mini)
    eb:SetAutoFocus(false)
    T.SetFont(eb, 12, true)
    eb:SetPoint("TOPLEFT", 10, -6)
    eb:SetPoint("BOTTOMRIGHT", -10, 6)
    eb:SetScript("OnEscapePressed", function() mini:Hide() end)
    eb:SetScript("OnEditFocusLost", function() mini:Hide() end)
    eb:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(mini.text) self:HighlightText() end
    end)
    eb:SetScript("OnKeyDown", function(_, key)
        if key == "C" and IsControlKeyDown() then C_Timer.After(0, function() mini:Hide() end) end
    end)
    mini.eb = eb
    mini.measure = T.Text(mini, 12, "text")
    mini.measure:Hide()
end

function CopyBox.Name(text)
    if not mini then BuildMini() end
    mini.text = text
    mini.measure:SetText(text)
    mini:SetSize(math.max(80, mini.measure:GetStringWidth() + 28), 28)
    local x, y = GetCursorPosition()
    local scale = mini:GetEffectiveScale()
    mini:ClearAllPoints()
    mini:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale - 10, y / scale - 14)
    mini:Show()
    mini.eb:SetText(text)
    mini.eb:SetFocus()
    mini.eb:HighlightText()
end
