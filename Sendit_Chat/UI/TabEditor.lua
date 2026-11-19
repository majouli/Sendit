--[[
  TabEditor: what a chat tab shows, laid out like Blizzard's chat settings:
  three pages (Chat: player and creature messages; Channels: the joined
  ones; Other: combat, PvP, system), each kind a switch with its colour
  (UI/ChatColors.lua, Blizzard's own chat colours). Own tabs also get a
  name. Opened by "+" on the main window and the right-click menu of
  General and of own tabs (Core/Tabs.lua). Named SenditTabEditor (no "chat"
  in the name, so Fade's group-chat peek leaves it alone); Escape closes it.

  TabEditor.Open()        a new tab
  TabEditor.Open(index)   change that tab (1 = General, else an own tab)
  An existing tab's changes apply however the editor closes (button, X,
  Escape); a new tab is made only by the save button.
]]
local _, ns = ...
local T, Widgets, Tabs, ChatKinds, ChatColors = ns.Theme, ns.Widgets, ns.Tabs, ns.ChatKinds, ns.ChatColors
local L = ns.L

local TabEditor = {}
ns.TabEditor = TabEditor

local WIDTH, ROW, HEAD, GAP = 500, 22, 20, 16
local COL = (WIDTH - 2 * GAP - GAP) / 2
local PAGES = { "chat", "channels", "other" }
local WHISPERS = { WHISPER = true, BN_WHISPER = true }

local box, editing, take, page
local pending, Apply  -- Apply: below (the editor's OnHide calls it)
local rows, heads = {}, {}

local function Build()
    box = T.Panel(UIParent, "DIALOG", "SenditTabEditor")
    box:SetWidth(WIDTH)
    box:SetPoint("CENTER")
    box:SetClampedToScreen(true)
    box:EnableMouse(true)
    T.Decorate(box, "panel")
    box.title = T.Text(box, 13, "text")
    box.title:SetPoint("TOPLEFT", GAP, -14)
    local close = Widgets.IconButton(box, "close", "CLOSE", function() box:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -10)
    box.name = Widgets.Input(box, "TAB_NAME")
    box.name:SetHeight(26)
    box.name:SetMaxLetters(24)
    box.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box.pages = Widgets.Segmented(box, "", {
        { "chat", "" }, { "channels", "" }, { "other", "" },
    }, function() return page end, function(v) page = v; TabEditor.Fill() end)
    box.pages:SetSize(WIDTH - 2 * GAP, 24)
    box.hint = T.Text(box, 10, "textMuted")
    box.hint:SetJustifyH("LEFT")
    box.list = CreateFrame("Frame", nil, box)
    box.empty = T.Text(box.list, 11, "textMuted")
    box.empty:SetPoint("TOPLEFT")
    box.save = Widgets.Button(box, "", function() TabEditor.Save() end)
    box.save:SetSize(WIDTH - 2 * GAP, 26)
    box.save:SetPoint("BOTTOM", 0, 14)
    table.insert(UISpecialFrames, "SenditTabEditor")
    box:SetScript("OnHide", function() Apply() end)
end

-- A page as a list of heads ({ head = text }) and switches ({ key, label, color }).
local function Items(p)
    local items = {}
    if p == "channels" then
        for _, c in ipairs(Tabs.Channels(take)) do
            items[#items + 1] = { key = c[1], label = c[2], color = Tabs.ChannelType(c[1]) }
        end
        return items
    end
    for _, s in ipairs(ChatKinds.Sections()) do
        if s.id == p then
            for _, h in ipairs(s.heads) do
                items[#items + 1] = { head = L[h.label] }
                for _, key in ipairs(h.keys) do
                    -- whispers never reach the chat while the messenger takes them
                    if not (WHISPERS[key] and ns.db.splitWhispers) then
                        items[#items + 1] = { key = key, label = ChatKinds.Label(key), color = ChatKinds.ColorType(key),
                            also = ChatKinds.Types(key) }
                    end
                end
            end
        end
    end
    return items
end

local function Height(items)
    local h = 0
    for _, it in ipairs(items) do h = h + (it.head and HEAD or ROW) end
    return h
end

local function Row(k)
    if rows[k] then return rows[k] end
    local r
    r = Widgets.Switch(box.list, "", function() return r ~= nil and r.key ~= nil and take[r.key] ~= nil end,
        function(on) take[r.key] = on and r.labelText or nil end)
    r:SetWidth(COL)
    r.label:ClearAllPoints()
    r.label:SetPoint("LEFT", 22, 0)
    r.swatch = ChatColors.Swatch(r)
    r.swatch:SetPoint("LEFT", 2, 0)
    rows[k] = r
    return r
end

local function Head(k)
    if heads[k] then return heads[k] end
    heads[k] = T.Text(box.list, 10, "accent")
    return heads[k]
end

-- Two columns, the second starts once the first holds half the page (a
-- head never ends a column).
function TabEditor.Fill()
    local items = Items(page)
    local half, y, x = Height(items) / 2, 0, 0
    local nr, nh = 0, 0
    for _, it in ipairs(items) do
        if x == 0 and y > 0 and (y >= half or (it.head and y + HEAD >= half)) then x, y = COL + GAP, 0 end
        local obj
        if it.head then
            nh = nh + 1
            obj = Head(nh)
            obj:SetText(it.head)
        else
            nr = nr + 1
            obj = Row(nr)
            obj.key, obj.labelText = it.key, it.label
            obj.label:SetText(it.label)
            obj.swatch:Set(it.color, nil, it.also)
            obj.Refresh()
        end
        obj:ClearAllPoints()
        obj:SetPoint("TOPLEFT", box.list, "TOPLEFT", x, it.head and -(y + 6) or -y)
        obj:Show()
        y = y + (it.head and HEAD or ROW)
    end
    for i = nr + 1, #rows do rows[i]:Hide() end
    for i = nh + 1, #heads do heads[i]:Hide() end
    box.empty:SetText(nr == 0 and L.TAB_NO_CHANNELS or "")
    box.pages.Refresh()
end

-- The tallest page decides the height, so switching pages keeps the size.
local function Layout(general)
    local y = -42
    box.name:SetShown(not general)
    if not general then
        box.name:ClearAllPoints()
        box.name:SetPoint("TOPLEFT", GAP, y)
        box.name:SetPoint("RIGHT", -GAP, 0)
        y = y - 34
    end
    box.pages:ClearAllPoints()
    box.pages:SetPoint("TOPLEFT", GAP, y)
    y = y - 30
    box.hint:ClearAllPoints()
    box.hint:SetPoint("TOPLEFT", GAP, y)
    box.hint:SetPoint("RIGHT", -GAP, 0)
    y = y - 26
    local tallest = 0
    for _, p in ipairs(PAGES) do
        local items = Items(p)
        local h = Height(items) / 2 + HEAD + ROW
        if h > tallest then tallest = h end
    end
    box.list:ClearAllPoints()
    box.list:SetPoint("TOPLEFT", GAP, y)
    box.list:SetSize(WIDTH - 2 * GAP, tallest)
    box:SetHeight(-y + tallest + 56)
end

function TabEditor.Open(index)
    if not box then Build() end
    local general = index == 1
    editing = (general or Tabs.Get(index)) and index or nil
    take = Tabs.Take(editing)
    page = "chat"
    -- texts on every open: the suite language can change in between
    box.title:SetText(general and L.GENERAL_SETTINGS or editing and L.EDIT_TAB or L.NEW_TAB)
    box.hint:SetText(general and L.GENERAL_HINT or L.TAB_HINT)
    box.save.text:SetText(L.SAVE_TAB)
    local texts = { L.KINDS_CHAT, L.TAB_CHANNELS, L.KINDS_OTHER }
    for i, b in ipairs(box.pages.buttons) do b.text:SetText(texts[i]) end
    local t = Tabs.Get(editing)
    box.name:SetText(t and t.name or "")
    Layout(general)
    TabEditor.Fill()
    pending = true
    box:Show()
    if not editing then box.name:SetFocus() end
end

-- Applied however the editor closes (save button, X, Escape), as Blizzard's
-- chat settings apply at once; a new tab only by the save button (closing
-- a new one cancels it).
function Apply(saved)
    if not pending then return end
    pending = false
    local name = ""
    if editing ~= 1 then
        name = strtrim(box.name:GetText() or "")
        if not editing and not saved then return end
        if name == "" then
            for _, key in ipairs(ChatKinds.All()) do
                if take[key] then name = take[key] break end
            end
            if name == "" then for _, label in pairs(take) do name = label break end end
        end
        if name == "" then name = L.NEW_TAB end
    end
    local index = Tabs.Save(editing, name, take)
    ns.Windows.Refresh()
    local main = ns.Windows.Main()
    if main and not editing then
        for _, i in ipairs(main.tabs) do if i == index then main:Select(index) end end
    end
end

function TabEditor.Save()
    Apply(true)
    box:Hide()
end
