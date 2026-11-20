--[[
  ErrorPage: the Errors page (/sendit errors) - debug switch, one row per error (count, time, addon,
  message), the picked one in full (selectable) with Copy and Clear; follows new errors live.
]]
local _, ns = ...

local Options, T, W, L, ErrorLog = ns.Options, ns.Theme, ns.Widgets, ns.L, ns.ErrorLog
local function Tx(key) return ns.Locale.Text(L, key) end

local LIST_ROWS, ROW_H = 6, 26
local DETAIL_H = 190

local picked

-- "Sendit_Chat/UI/Messenger.lua:120: attempt ..." -> "Chat", the rest
local function Split(message)
    local addon = message:match("Sendit_(%w+)") or (message:find("Sendit") and "Sendit") or "?"
    local text = message:gsub("^.-AddOns[/\\]", ""):gsub("\n.*", "")
    return addon, text
end

local function NewRow(parent, onClick)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW_H)
    r.sel = T.Fill(r, "selected", "BACKGROUND")
    r.sel:SetAllPoints()
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    r.count = T.Text(r, "small", "accent")
    r.count:SetPoint("LEFT", 12, 0)
    r.count:SetWidth(34)
    r.when = T.Text(r, "small", "textMuted")
    r.when:SetPoint("LEFT", 50, 0)
    r.addon = T.Text(r, "small", "text")
    r.addon:SetPoint("LEFT", 130, 0)
    r.text = T.Text(r, "small", "textDim")
    r.text:SetPoint("LEFT", 214, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -12, 0)
    r:SetScript("OnClick", onClick)
    return r
end

local function BuildLog(parent)
    local block = CreateFrame("Frame", nil, parent)

    local list = CreateFrame("Frame", nil, block)
    list:SetPoint("TOPLEFT")
    list:SetPoint("RIGHT", block, "RIGHT", 0, 0)
    list:SetHeight(LIST_ROWS * ROW_H + 2)
    T.Fill(list, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(list, "border")
    local empty = T.Text(list, "note", "textMuted")
    empty:SetPoint("CENTER")
    local rows, offset = {}, 0
    list:EnableMouseWheel(true)

    local details = CreateFrame("Frame", nil, block)
    details:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -10)
    details:SetPoint("RIGHT", block, "RIGHT", 0, 0)
    details:SetHeight(DETAIL_H)
    T.Fill(details, "panelAlt", "BACKGROUND"):SetAllPoints()
    T.Border(details, "border")
    local scroll = CreateFrame("ScrollFrame", nil, details, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local report = CreateFrame("EditBox", nil, scroll)
    report:SetMultiLine(true)
    report:SetAutoFocus(false)
    T.SetFont(report, 11, nil, _G["ChatFontNormal"])
    T.Paint(report, "textDim")
    report:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(report)
    scroll:SetScript("OnSizeChanged", function(_, w) report:SetWidth(w) end)

    local copy = W.Button(block, "", function()
        report:SetFocus()
        report:HighlightText()
    end)
    copy:SetPoint("TOPRIGHT", details, "BOTTOMRIGHT", 0, -10)
    local clear = W.Button(block, "", function()
        picked = nil
        ErrorLog.Clear()
    end)
    clear:SetPoint("RIGHT", copy, "LEFT", -8, 0)
    block:SetHeight(LIST_ROWS * ROW_H + 2 + 10 + DETAIL_H + 10 + 30)

    function block:Refresh()
        local entries = ErrorLog.List()
        local present = false
        for _, e in ipairs(entries) do if e == picked then present = true end end
        if not present then picked = nil end
        picked = picked or entries[1]
        offset = math.max(0, math.min(offset, #entries - LIST_ROWS))
        for i = 1, LIST_ROWS do
            local e = entries[i + offset]
            local r = rows[i] or NewRow(list, function(self)
                picked = self.entry
                block:Refresh()
            end)
            rows[i] = r
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
            r:SetPoint("RIGHT", list, "RIGHT", -1, 0)
            r.entry = e
            r:SetShown(e ~= nil)
            if e then
                local addon, text = Split(e.message or "?")
                r.count:SetText((e.count or 1) .. "x")
                r.when:SetText(date("%d.%m. %H:%M", e.last or e.first or time()))
                r.addon:SetText(addon)
                r.text:SetText(text)
                r.sel:SetShown(e == picked)
            end
        end
        empty:SetText(#entries == 0 and (ErrorLog.Enabled() and L.ERRORS_NONE or L.ERRORS_OFF) or "")
        report:SetText(ErrorLog.Report(picked))
        report:SetCursorPosition(0)
        copy:SetLabel(L.ERRORS_COPY)
        clear:SetLabel(L.ERRORS_CLEAR)
        copy:SetEnabled(picked ~= nil)
        clear:SetEnabled(#entries > 0)
    end
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta
        block:Refresh()
    end)
    return block
end

Options:Register({
    key = "errors",
    core = true,
    title = Tx("ERRORS"),
    subtitle = Tx("ERRORS_SUB"),
    build = Options.SettingsPage(function(Lay, c)
        Lay:Section(Tx("DIAGNOSTICS"))
        Lay:Row(Tx("DEBUG_MODE"), Tx("DEBUG_MODE_DESC"), W.Switch(c,
            function() return ErrorLog.Enabled() end,
            function(on)
                ErrorLog.SetEnabled(on)
                Options.Changed()
            end))
        Lay:EndSection()
        local log = BuildLog(c)
        Lay:Place(log, log:GetHeight())
        ErrorLog.OnChange(function()
            if Options:Current() and Options:Current().key == "errors" then log:Refresh() end
        end)
    end),
})
