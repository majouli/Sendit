--[[
  TabEditor: create or change one of Sendit Chat's own tabs (Core/Tabs.lua):
  a name and switches for what it takes from General - message kinds first,
  then the channels the player has joined. Opened by "+" on the main window
  and an own tab's right-click menu. Named SenditTabEditor (no "chat" in the
  name, so Fade's group-chat peek leaves it alone); Escape closes it.

  TabEditor.Open()        a new tab
  TabEditor.Open(index)   change that own tab
]]
local _, ns = ...
local T, Widgets, Tabs = ns.Theme, ns.Widgets, ns.Tabs
local L = ns.L

local TabEditor = {}
ns.TabEditor = TabEditor

local WIDTH, ROW, TOP = 300, 24, 104

local box, editing, take
local rows, heads = {}, {}

local function Build()
    box = T.Panel(UIParent, "DIALOG", "SenditTabEditor")
    box:SetWidth(WIDTH)
    box:SetPoint("CENTER")
    box:SetClampedToScreen(true)
    box:EnableMouse(true)
    T.Decorate(box, "panel")
    box.title = T.Text(box, 13, "text")
    box.title:SetPoint("TOPLEFT", 16, -14)
    local close = Widgets.IconButton(box, "close", "CLOSE", function() box:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -10)
    box.name = Widgets.Input(box, "TAB_NAME")
    box.name:SetPoint("TOPLEFT", 16, -42)
    box.name:SetPoint("RIGHT", -16, 0)
    box.name:SetHeight(26)
    box.name:SetMaxLetters(24)
    box.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box.hint = T.Text(box, 10, "textMuted")
    box.hint:SetPoint("TOPLEFT", 16, -76)
    box.hint:SetPoint("RIGHT", -16, 0)
    box.hint:SetJustifyH("LEFT")
    box.save = Widgets.Button(box, "", function() TabEditor.Save() end)
    box.save:SetSize(WIDTH - 32, 26)
    box.save:SetPoint("BOTTOM", 0, 14)
    table.insert(UISpecialFrames, "SenditTabEditor")
end

local function Head(k, text, y)
    local h = heads[k] or T.Text(box, 10, "accent")
    heads[k] = h
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 16, y)
    h:SetText(text)
    h:Show()
end

-- The switches: kinds, then channels (with a channel this tab took earlier
-- but the player has left, so it can still be switched off).
local function Fill()
    local choices, seen = Tabs.Choices(), {}
    for _, c in ipairs(choices) do seen[c[1]] = true end
    for key, label in pairs(take) do
        if not seen[key] then choices[#choices + 1] = { key, label, channel = true } end
    end
    local y, k, channelHead = -TOP, 0, false
    Head(1, L.TAB_KINDS, y)
    y = y - 18
    for _, c in ipairs(choices) do
        if c.channel and not channelHead then
            channelHead = true
            y = y - 8
            Head(2, L.TAB_CHANNELS, y)
            y = y - 18
        end
        k = k + 1
        local row = rows[k]
        if not row then
            local r
            r = Widgets.Switch(box, "", function() return r ~= nil and take[r.key] ~= nil end,
                function(on) take[r.key] = on and r.labelText or nil end)
            r:SetWidth(WIDTH - 32)
            rows[k], row = r, r
        end
        row.key, row.labelText = c[1], c[2]
        row.label:SetText(c[2])
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 16, y)
        row.Refresh()
        row:Show()
        y = y - ROW
    end
    if heads[2] then heads[2]:SetShown(channelHead) end
    for i = k + 1, #rows do rows[i]:Hide() end
    box:SetHeight(-y + 56)
end

function TabEditor.Open(index)
    if not box then Build() end
    local t = Tabs.Get(index)
    editing = t and index or nil
    take = {}
    if t then for key, label in pairs(t.take or {}) do take[key] = label end end
    -- texts on every open: the suite language can change in between
    box.title:SetText(t and L.EDIT_TAB or L.NEW_TAB)
    box.hint:SetText(L.TAB_HINT)
    box.save.text:SetText(L.SAVE_TAB)
    box.name:SetText(t and t.name or "")
    Fill()
    box:Show()
    if not t then box.name:SetFocus() end
end

function TabEditor.Save()
    local name = strtrim(box.name:GetText() or "")
    if name == "" then
        for _, row in ipairs(rows) do
            if row:IsShown() and take[row.key] then name = row.labelText break end
        end
    end
    if name == "" then name = L.NEW_TAB end
    local index = Tabs.Save(editing, name, take)
    box:Hide()
    ns.Windows.Refresh()
    local main = ns.Windows.Main()
    if main and not editing then
        for _, i in ipairs(main.tabs) do if i == index then main:Select(index) end end
    end
end
