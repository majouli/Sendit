--[[
  ChatWindow: Sendit Chat's chat windows.

  Window 1 is the main window: it holds every mirrored Blizzard chat window
  (tab) that is not detached. A tab is detached into its own window by
  dragging it out of its window or with its right-click menu; dropping it on
  another window (or "Back to the main window") moves it there. Each tab has
  one ScrollingMessageFrame (the widget Blizzard renders chat with: wrapping,
  scrolling, secret text) that moves between windows.

  Windows are anchored BOTTOMLEFT, so minimizing collapses a window onto its
  header at the bottom edge, where the chat input sits.

  Saved in ns.acct.windows[id] = { x, y, w, h, minimized, selected, tabs }
  (tabs only for detached windows; the main window takes the rest).

  Own tabs (Core/Tabs.lua) sit beside Blizzard's: "+" after the main
  window's tabs opens the tab editor (UI/TabEditor.lua); a main-window line
  an own tab takes goes there instead of General.

  Lines arrive through UI/ChatLines.lua (Windows.Arrived marks them). The
  combat log tab leaves room at the top for its filter strip
  (UI/CombatFilters.lua).

  Windows.Main()             the main window object
  Windows.Refresh()          re-assign tabs (Blizzard windows changed)
  Windows.Apply()            look: font, background, border, lock
  Windows.Reset()            default positions
  Windows.Arrived(index, quiet)  a line came into that tab (UI/ChatLines.lua)
  Windows.DeleteTab(index)   remove an own tab (Core/Tabs.lua)
  Windows.CombatLogBody()    the combat log tab's body while it is shown
]]
local _, ns = ...
local T, Widgets, Safe, Links, Mirror = ns.Theme, ns.Widgets, ns.Safe, ns.Links, ns.Mirror
local History, Tabs = ns.History, ns.Tabs
local L = ns.L

local Windows = {}
ns.Windows = Windows

local HEADER = 24
local PAD = 8
local MAIN_DEFAULT = { x = 20, y = 52, w = 460, h = 210 }
local COMBAT_STRIP = 26  -- room for the combat log's filter strip

local smfs = {}     -- [index] = ScrollingMessageFrame
local unread = {}   -- [index] = true while a line waits unseen
local owner = {}    -- [index] = window that shows the tab
local list = {}     -- [id] = window
local holder = CreateFrame("Frame")
holder:Hide()

local function Saved(id)
    local all = ns.acct.windows
    all[id] = all[id] or {}
    return all[id]
end

local function Locked() return ns.db.locked end

---------------------------------------------------------------------------
-- Message frames
---------------------------------------------------------------------------
local function UpdateDown(win)
    if not win or not win.down then return end
    local smf = smfs[win.selected]
    local atBottom = true
    if smf and smf.AtBottom then atBottom = Safe.Call(smf.AtBottom, smf) ~= false end
    win.down:SetShown(not atBottom and not Saved(win.id).minimized)
end

local function Wheel(self, delta)
    if IsControlKeyDown() then
        if delta > 0 then self:ScrollToTop() else self:ScrollToBottom() end
    elseif IsShiftKeyDown() then
        if delta > 0 then self:PageUp() else self:PageDown() end
    else
        for _ = 1, 3 do
            if delta > 0 then self:ScrollUp() else self:ScrollDown() end
        end
    end
    UpdateDown(owner[self.senditIndex])
end

local function ApplyFont(smf)
    T.SetFont(smf, ns.db.fontSize, true)
    smf:SetSpacing(math.floor(ns.db.fontSize * 0.18 + 0.5))
end

local function SMF(index)
    local smf = smfs[index]
    if smf then return smf end
    smf = CreateFrame("ScrollingMessageFrame", nil, holder)
    smf.senditIndex = index
    smf:SetJustifyH("LEFT")
    smf:SetMaxLines(1500)
    smf:SetFading(false)
    smf:SetShadowOffset(1, -1)
    smf:SetShadowColor(0, 0, 0, 0.7)
    if smf.SetIndentedWordWrap then smf:SetIndentedWordWrap(true) end
    ApplyFont(smf)
    smf:EnableMouseWheel(true)
    smf:SetScript("OnMouseWheel", Wheel)
    Links.Attach(smf)
    smfs[index] = smf
    return smf
end
Windows._SMF = SMF

---------------------------------------------------------------------------
-- A line arrived in a tab (UI/ChatLines.lua): unread dot when it is not
-- the shown tab (unless quiet: the combat log), else the scroll-down button.
---------------------------------------------------------------------------
function Windows.Arrived(index, quiet)
    local win = owner[index]
    if not quiet and (not win or win.selected ~= index or Saved(win.id).minimized) then
        unread[index] = true
        if win then win:UpdateTabs() end
    else
        UpdateDown(win)
    end
end

---------------------------------------------------------------------------
-- Window object
---------------------------------------------------------------------------
local Win = {}
Win.__index = Win

function Win:SavePosition()
    local d = Saved(self.id)
    local f = self.frame
    d.x, d.y = f:GetLeft(), f:GetBottom()
    if not d.minimized then d.w, d.h = f:GetWidth(), f:GetHeight() end
end

function Win:Place()
    local d = Saved(self.id)
    local def = self.id == 1 and MAIN_DEFAULT or { x = 520, y = 260, w = 380, h = 190 }
    local f = self.frame
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", d.x or def.x, d.y or def.y)
    f:SetSize(d.w or def.w, d.minimized and HEADER or (d.h or def.h))
    self.body:SetShown(not d.minimized)
    self.grip:SetShown(not d.minimized and not Locked())
    self.minBtn:SetKind(d.minimized and "restore" or "minimize")
    UpdateDown(self)
end

function Win:ToggleMinimized()
    local d = Saved(self.id)
    if not d.minimized then self:SavePosition() end
    d.minimized = not d.minimized
    if not d.minimized and self.selected then unread[self.selected] = nil end
    self:Place()
    self:UpdateTabs()
    if self.id == 1 and ns.Input then ns.Input.Anchor() end
end

function Win:Select(index)
    self.selected = index
    Saved(self.id).selected = index
    unread[index] = nil
    for _, i in ipairs(self.tabs) do
        local smf = smfs[i]
        if smf then smf:SetShown(i == index) end
    end
    self:UpdateTabs()
    UpdateDown(self)
end

function Win:UpdateTabs()
    local x = 4
    for k, index in ipairs(self.tabs) do
        local b = self.tabButtons[k]
        if not b then
            b = self:NewTab()
            self.tabButtons[k] = b
        end
        b.index = index
        b.text:SetText(Tabs.Name(index))
        local sel = index == self.selected and not Saved(self.id).minimized
        T.Color(b.text, sel and "text" or "textMuted")
        b.line:SetShown(sel)
        b.dot:SetShown(unread[index] == true)
        local w = math.floor((b.text:GetStringWidth() or 40) + 18)
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self.header, "BOTTOMLEFT", x, 0)
        b:Show()
        x = x + w
    end
    for k = #self.tabs + 1, #self.tabButtons do self.tabButtons[k]:Hide() end
    if self.addBtn then
        self.addBtn:ClearAllPoints()
        self.addBtn:SetPoint("BOTTOMLEFT", self.header, "BOTTOMLEFT", x + 2, 2)
    end
end

local function WindowUnderCursor()
    for _, w in pairs(list) do
        if w.frame:IsShown() and w.frame:IsMouseOver() then return w end
    end
    return nil
end

function Win:TabMenu(button)
    local index = button.index
    local items = {}
    if self.id == 1 then
        if #self.tabs > 1 then
            items[#items + 1] = { L.DETACH, function() Windows.Detach(index) end }
        end
    else
        items[#items + 1] = { L.DOCK, function() Windows.Move(index, 1) end }
    end
    items[#items + 1] = { L.COPY_TEXT, function() ns.ChatLines.Copy(index) end }
    if index == 1 then
        items[#items + 1] = { L.GENERAL_SETTINGS, function() ns.TabEditor.Open(1) end }
    elseif Tabs.Get(index) then
        items[#items + 1] = { L.EDIT_TAB, function() ns.TabEditor.Open(index) end }
        items[#items + 1] = { L.DELETE_TAB, function() Windows.DeleteTab(index) end }
    end
    Widgets.Menu(button, items)
end

function Win:NewTab()
    local b = CreateFrame("Button", nil, self.header)
    b:SetHeight(HEADER)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.text = T.Text(b, 11, "textMuted")
    b.text:SetPoint("CENTER", 0, 1)
    b.line = T.Tex(b, "ARTWORK", "accent", 1)
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 6, 0)
    b.line:SetPoint("BOTTOMRIGHT", -6, 0)
    b.dot = T.Tex(b, "OVERLAY", "accent", 1)
    b.dot:SetSize(4, 4)
    b.dot:SetPoint("TOPRIGHT", -3, -6)
    b:SetScript("OnClick", function(btn, mouse)
        if mouse == "RightButton" then
            self:TabMenu(btn)
            return
        end
        if Saved(self.id).minimized then self:ToggleMinimized() end
        self:Select(btn.index)
    end)
    b:SetScript("OnDragStart", function(btn)
        if Locked() then return end
        btn:SetAlpha(0.4)
        self.dragging = btn.index
        ns.TabDrag.Start(Tabs.Name(btn.index), function()
            local w = WindowUnderCursor()
            return w and w ~= self and w.frame or nil
        end)
    end)
    b:SetScript("OnDragStop", function(btn)
        btn:SetAlpha(1)
        ns.TabDrag.Stop()
        local index = self.dragging
        self.dragging = nil
        if not index or Locked() then return end
        local target = WindowUnderCursor()
        if target == self then return end
        if target then
            Windows.Move(index, target.id)
        elseif self.id == 1 then
            local x, y = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            Windows.Detach(index, x / s - 40, y / s - 150)
        end
    end)
    return b
end

function Win:ApplyLook()
    local db = ns.db
    T.Color(self.frame.bg, "bg", db.bgAlpha)
    T.Color(self.headerBg, "header", math.min(1, db.bgAlpha + 0.08))
    T.SetBorder(self.frame, db.border)
    if self.lockBtn then
        self.lockBtn.active = db.locked
        self.lockBtn:SetKind(db.locked and "lock" or "unlock")
    end
    self.grip:SetShown(not Saved(self.id).minimized and not db.locked)
    if self.friendsBtn then self.friendsBtn:SetShown(db.friendsPanel ~= false) end
end

local function NewWindow(id)
    local self = setmetatable({ id = id, tabs = {}, tabButtons = {} }, Win)
    -- "Chat" in the name: UI faders that sort elements by name (Fade)
    -- recognise the window as a chat, e.g. to show it when the group writes.
    local f = CreateFrame("Frame", "SenditChatWindow" .. id, UIParent)
    self.frame = f
    f:SetFrameStrata("LOW")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    Widgets.Bounds(f, 220, 90, 1600, 1200)
    f.bg = T.Tex(f, "BACKGROUND", "bg", ns.db.bgAlpha)
    f.bg:SetAllPoints()
    T.Border(f, ns.db.border)
    T.Decorate(f, "window")

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER)
    self.header = header
    self.headerBg = T.Tex(header, "BACKGROUND", "header", 1, 1)
    self.headerBg:SetAllPoints()
    local divider = T.Tex(header, "BORDER", "ink", 0.08)
    divider:SetPoint("BOTTOMLEFT"); divider:SetPoint("BOTTOMRIGHT"); divider:SetHeight(1)
    Widgets.Drag(header, f, function() return not Locked() end, function() self:SavePosition() end)

    -- Right side controls, right to left.
    local x = -4
    local function Add(btn)
        btn:SetPoint("RIGHT", header, "RIGHT", x, 0)
        x = x - 22
        return btn
    end
    self.minBtn = Add(Widgets.IconButton(header, "minimize",
        function() return Saved(id).minimized and L.RESTORE or L.MINIMIZE end,
        function() self:ToggleMinimized() end))
    self.lockBtn = Add(Widgets.IconButton(header, "unlock",
        function() return ns.db.locked and L.LOCKED or L.UNLOCKED end,
        function()
            ns.db.locked = not ns.db.locked
            ns.Changed()
        end))
    -- the shown tab's text in the copy box (also in the tab's right-click menu)
    self.copyBtn = Add(Widgets.IconButton(header, "copy", "COPY_TEXT",
        function() if self.selected then ns.ChatLines.Copy(self.selected) end end))
    if id == 1 then
        self.settingsBtn = Add(Widgets.IconButton(header, "settings", "SETTINGS",
            function() ns.OpenSettings() end))
        self.msgBtn = Add(Widgets.IconButton(header, "messages", "MESSAGES",
            function() if ns.Messenger then ns.Messenger.Toggle() end end))
        self.badge = Widgets.Badge(self.msgBtn)
        self.badge:SetPoint("CENTER", self.msgBtn, "TOPRIGHT", -2, -3)
        self.friendsBtn = Add(Widgets.IconButton(header, "friends", "FRIENDS_TIP",
            function() if ns.FriendsPanel then ns.FriendsPanel.FromChat() end end))
        self.addBtn = Widgets.IconButton(header, "plus", function() return L.NEW_TAB end,
            function() ns.TabEditor.Open() end)
    end

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", PAD, -HEADER - 4)
    body:SetPoint("BOTTOMRIGHT", -PAD, 6)
    self.body = body

    local down = Widgets.IconButton(body, "down", nil, function()
        local smf = smfs[self.selected]
        if smf then smf:ScrollToBottom() end
        UpdateDown(self)
    end)
    down:SetPoint("BOTTOMRIGHT", 2, 0)
    down:SetFrameLevel(body:GetFrameLevel() + 10)
    down.bg = T.Tex(down, "BACKGROUND", "raised", 0.9)
    down.bg:SetAllPoints()
    down:Hide()
    self.down = down

    self.grip = Widgets.Grip(f, function() self:SavePosition() end)
    f:SetScript("OnSizeChanged", function()
        if self.id == 1 and ns.Input then ns.Input.Anchor() end
    end)
    list[id] = self
    return self
end

---------------------------------------------------------------------------
-- Tab assignment
---------------------------------------------------------------------------
function Windows.Main() return list[1] end
function Windows.Get(id) return list[id] end
function Windows.All() return list end

function Windows.Refresh()
    local valid, order = {}, Tabs.All()
    for _, i in ipairs(order) do valid[i] = true end
    local taken = {}
    -- Detached windows keep their tabs while those Blizzard windows exist.
    for id, d in pairs(ns.acct.windows) do
        if id ~= 1 and type(d) == "table" then
            local keep = {}
            for _, i in ipairs(d.tabs or {}) do
                if valid[i] and not taken[i] then keep[#keep + 1] = i; taken[i] = true end
            end
            d.tabs = keep
            if #keep == 0 then ns.acct.windows[id] = nil end
        end
    end
    local mainTabs = {}
    for _, i in ipairs(order) do if not taken[i] then mainTabs[#mainTabs + 1] = i end end
    if #mainTabs == 0 and #order > 0 then
        -- The main window never ends up empty: take the first tab back.
        local first = order[1]
        for id, d in pairs(ns.acct.windows) do
            if id ~= 1 and type(d) == "table" then
                for k, i in ipairs(d.tabs or {}) do if i == first then table.remove(d.tabs, k) end end
                if d.tabs and #d.tabs == 0 then ns.acct.windows[id] = nil end
            end
        end
        mainTabs = { first }
    end

    local assign = { [1] = mainTabs }
    for id, d in pairs(ns.acct.windows) do
        if id ~= 1 and type(d) == "table" then assign[id] = d.tabs end
    end
    wipe(owner)
    for id, tabs in pairs(assign) do
        local w = list[id] or NewWindow(id)
        w.tabs = tabs
        for _, i in ipairs(tabs) do
            local smf = SMF(i)
            smf:SetParent(w.body)
            smf:ClearAllPoints()
            smf:SetPoint("TOPLEFT", w.body, "TOPLEFT", 0, Mirror.IsCombatLog(i) and -COMBAT_STRIP or 0)
            smf:SetPoint("BOTTOMRIGHT", w.body, "BOTTOMRIGHT")
            owner[i] = w
        end
        w:Place()
        w:ApplyLook()
        w.frame:Show()
        local sel = Saved(id).selected
        local found = false
        for _, i in ipairs(tabs) do if i == sel then found = true end end
        w:Select(found and sel or tabs[1])
    end
    for id, w in pairs(list) do
        if not assign[id] then
            w.frame:Hide()
            w.tabs = {}
        end
    end
    Windows.UpdateBadge()
end

function Windows.Detach(index, x, y)
    local main = list[1]
    if not main or #main.tabs <= 1 or owner[index] ~= main then return end
    local id = 2
    while ns.acct.windows[id] do id = id + 1 end
    local mf = main.frame
    ns.acct.windows[id] = {
        tabs = { index }, selected = index, w = 380, h = 190,
        x = x or ((mf:GetLeft() or 0) + 40), y = y or ((mf:GetTop() or 300) + 20),
    }
    Windows.Refresh()
end

function Windows.Move(index, toId)
    for id, d in pairs(ns.acct.windows) do
        if id ~= 1 and type(d) == "table" and d.tabs then
            for k, i in ipairs(d.tabs) do
                if i == index then table.remove(d.tabs, k) break end
            end
        end
    end
    if toId ~= 1 then
        local d = ns.acct.windows[toId]
        if d then
            d.tabs = d.tabs or {}
            d.tabs[#d.tabs + 1] = index
            d.selected = index
        end
    else
        Saved(1).selected = index
    end
    Windows.Refresh()
end

function Windows.DeleteTab(index)
    Tabs.Delete(index)
    local smf = smfs[index]
    if smf then
        smf:Clear()
        smf:SetParent(holder)
        smfs[index] = nil
    end
    unread[index] = nil
    Windows.Refresh()
end

function Windows.Apply()
    for _, smf in pairs(smfs) do ApplyFont(smf) end
    for _, w in pairs(list) do
        w:ApplyLook()
        w:Place()
        w:UpdateTabs()  -- tab names follow a language switch
    end
end

function Windows.Reset()
    for id in pairs(ns.acct.windows) do
        if id == 1 then ns.acct.windows[1] = {} else
            local d = ns.acct.windows[id]
            d.x, d.y, d.w, d.h, d.minimized = nil, nil, nil, nil, nil
        end
    end
    Windows.Refresh()
    if ns.Input then ns.Input.Anchor() end
end

-- The combat log tab's body while that tab is the one shown, else nil.
function Windows.CombatLogBody()
    for index, w in pairs(owner) do
        if Mirror.IsCombatLog(index) and w.selected == index and not Saved(w.id).minimized
            and w.frame:IsShown() then
            return w.body
        end
    end
    return nil
end

function Windows.UpdateBadge()
    local main = list[1]
    -- number of conversations with unread messages (not of messages)
    if main and main.badge and ns.Whispers then main.badge:Set(ns.Whispers.UnreadChats()) end
end

ns.OnReady(function()
    local d = ns.Design()
    T.SetLook(d.palette, d.style)
    Windows.Refresh()        -- before UI/ChatLines.lua replays and sinks lines
    ns.OnChanged(function()
        local d = ns.Design()
        if T.style ~= d.style or T.palette ~= d.palette then T.SetLook(d.palette, d.style) end
        History.Sync()
        Windows.Apply()
    end)
    ns.Listen("UPDATE_CHAT_WINDOWS", Windows.Refresh)
    ns.Listen("UPDATE_FLOATING_CHAT_WINDOWS", Windows.Refresh)
    if ns.Whispers then ns.Whispers.OnChange(Windows.UpdateBadge) end
end)
