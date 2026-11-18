--[[
  CopyBox: a tab's text as plain lines (link markup removed), selected and
  ready for Ctrl+A / Ctrl+C. Opened from a tab's right-click menu and the
  messenger's copy button (Conversation.Copy).
  Named SenditCopyBox - no "chat" in the name, so Fade's group-chat peek
  does not flash it. Escape closes it.

  CopyBox.Show(lines)   lines = { { text, ... }, ... } (History.Lines(index))
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
