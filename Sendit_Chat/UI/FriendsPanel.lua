--[[
  FriendsPanel: the friends list docked beside the messenger (right, or left without room); moves, fades
  and hides with it; open state in ns.acct.friendsOpen, off with friendsPanel. Rows: avatar with status
  dot, name, character and level, zone; left click whispers, right click our menu (message, invite, pin,
  online notice, note, copy name, archive, Blizzard's menu). Data: Core/Friends.lua.
  FriendsPanel.Toggle() / Open() / Close() / IsOpen() / FromChat() / Sync()
]]
local _, ns = ...
local T, Widgets, F = ns.Theme, ns.Widgets, ns.Friends
local L = ns.L

local FriendsPanel = {}
ns.FriendsPanel = FriendsPanel

local WIDTH, HEADER, ROW, SECTION, GAP = 236, 44, 44, 26, 6

local panel, content, emptyText
local rows, offlineOpen = {}, false
local filter = ""

local function Enabled() return ns.db and ns.db.friendsPanel ~= false end
local function Wanted() return ns.acct and ns.acct.friendsOpen ~= false end

local function Messenger() return ns.Messenger and ns.Messenger.Frame() end

local STATUS = { online = "online", afk = "away", dnd = "busy", offline = "ink" }

local function Status(e)
    if not e.online then return "offline" end
    if e.dnd then return "dnd" end
    if e.afk then return "afk" end
    return "online"
end

local function DotColor(dot, status)
    if status == "online" then dot:SetVertexColor(0.30, 0.85, 0.40, 1)
    elseif status == "afk" then dot:SetVertexColor(1.00, 0.62, 0.18, 1)
    elseif status == "dnd" then dot:SetVertexColor(0.95, 0.30, 0.30, 1)
    else dot:SetVertexColor(0.45, 0.47, 0.52, 1) end
end

local function Sub(e)
    if not e.online then return (e.note and e.note ~= "") and e.note or L.FRIENDS_OFFLINE end
    if e.inWoW then return e.area or e.realm or "" end
    if e.rich and e.rich ~= "" then return e.rich end
    return L.FRIENDS_APP
end

local function NameLine(e)
    local extra = ""
    if e.bn and e.character and e.online then
        extra = " |cff8a8f9c(" .. e.character .. (e.level and (" " .. L.LEVEL_SHORT:format(e.level)) or "") .. ")|r"
    elseif not e.bn and e.level and e.online then
        extra = " |cff8a8f9c" .. L.LEVEL_SHORT:format(e.level) .. "|r"
    end
    return e.name .. extra
end

local function NewRow()
    local r = CreateFrame("Button", nil, content)
    r:SetHeight(ROW)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.hl = T.Tex(r, "BACKGROUND", "ink", 0)
    r.hl:SetAllPoints()
    r.avatar = T.Avatar(r, 30)
    r.avatar:SetPoint("LEFT", 10, 0)
    r.dot = r.avatar:CreateTexture(nil, "OVERLAY", nil, 7)
    r.dot:SetTexture(T.WHITE)
    r.dot:SetSize(8, 8)
    r.dot:SetPoint("BOTTOMRIGHT", r.avatar, "BOTTOMRIGHT", 1, -1)
    Sendit.Theme.RoundOff(r.dot)
    r.name = T.Text(r, 12, "text")
    T.Own(r.name)
    r.name:SetPoint("TOPLEFT", r.avatar, "TOPRIGHT", 9, -1)
    r.name:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    -- marks: online notice, note
    r.bell = CreateFrame("Frame", nil, r)
    r.bell:SetSize(16, 16)
    r.bell:SetPoint("RIGHT", -6, 0)
    T.Icon(r.bell, "bell", "accent")
    r.noteMark = CreateFrame("Frame", nil, r)
    r.noteMark:SetSize(16, 16)
    T.Icon(r.noteMark, "note", "textMuted")
    r.name:SetWordWrap(false)
    r.sub = T.Text(r, 10, "textMuted")
    r.sub:SetPoint("BOTTOMLEFT", r.avatar, "BOTTOMRIGHT", 9, 1)
    r.sub:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r.sub:SetWordWrap(false)
    r:SetScript("OnEnter", function(self) T.Color(self.hl, "ink", 0.06) end)
    r:SetScript("OnLeave", function(self) T.Color(self.hl, "ink", 0) end)
    r.pin = T.Tex(r, "BORDER", "accent", 1)
    T.Own(r.pin)
    r.pin:SetPoint("TOPLEFT"); r.pin:SetPoint("BOTTOMLEFT"); r.pin:SetWidth(2)
    r:SetScript("OnClick", function(self, button)
        if not self.entry then return end
        if button == "RightButton" then FriendsPanel.Menu(self.entry)
        else F.Open(self.entry, ns.db.friendsCharClick) end
    end)
    return r
end

local function NewSection()
    local s = CreateFrame("Button", nil, content)
    s:SetHeight(SECTION)
    s.text = T.Text(s, 10, "textMuted")
    s.text:SetPoint("LEFT", 12, 0)
    s.line = T.Tex(s, "BORDER", "ink", 0.08)
    s.line:SetPoint("LEFT", s.text, "RIGHT", 8, 0)
    s.line:SetPoint("RIGHT", -10, 0)
    s.line:SetHeight(1)
    return s
end

local function FillRow(r, e)
    r.entry = e
    r.avatar:Set(e.name, e.class)
    local cr, cg, cb = T.ClassRGB(e.class)
    if e.bn then cr, cg, cb = T.RGB("bn") end
    r.name:SetText(NameLine(e))
    r.name:SetTextColor(cr, cg, cb, e.online and 1 or 0.55)
    r.sub:SetText(Sub(e))
    DotColor(r.dot, Status(e))
    r.avatar:SetAlpha(e.online and 1 or 0.5)
    r.pin:SetShown(e.favorite == true)
    local watched, noted = F.Watched(e), e.note ~= nil and e.note ~= ""
    r.bell:SetShown(watched)
    r.noteMark:SetShown(noted)
    r.noteMark:ClearAllPoints()
    r.noteMark:SetPoint("RIGHT", watched and r.bell or r, watched and "LEFT" or "RIGHT", watched and -2 or -6, 0)
    local marks = (watched and 18 or 0) + (noted and 18 or 0)
    r.name:SetPoint("RIGHT", r, "RIGHT", -10 - marks, 0)
    r.sub:SetPoint("RIGHT", r, "RIGHT", -10 - marks, 0)
    r.pin:SetVertexColor(T.RGB("accent"))
end

StaticPopupDialogs["SENDIT_FRIEND_NOTE"] = {
    text = "%s", button1 = _G["OKAY"] or "OK", button2 = _G["CANCEL"] or "Cancel",
    hasEditBox = 1, maxLetters = 127,
    OnShow = function(self, e)
        local box = self.editBox or (self.GetEditBox and self:GetEditBox())
        if box and e then box:SetText(e.note or "") box:HighlightText() end
    end,
    OnAccept = function(self, e)
        local box = self.editBox or (self.GetEditBox and self:GetEditBox())
        if box and e then F.SetNote(e, box:GetText()) end
    end,
    EditBoxOnEnterPressed = function(box)
        local dialog = box:GetParent()
        if dialog and dialog.data then F.SetNote(dialog.data, box:GetText()) end
        if dialog then dialog:Hide() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function Conversation(e)
    if e.bn then
        for _, c in ipairs(ns.Whispers.List()) do if c.bn and c.target == e.tag then return c end end
        for _, c in ipairs(ns.Whispers.Archived()) do if c.bn and c.target == e.tag then return c end end
        return nil
    end
    return ns.Whispers.Get("p:" .. (e.character or e.name):lower())
end

function FriendsPanel.Menu(e)
    local items = {}
    local function Add(text, fn, checked) items[#items + 1] = { text, fn, checked } end
    local char = F.CharacterName(e)
    if e.bn then Add(L.FR_WHISPER_BN, function() F.Open(e, false) end) end
    if char and (not e.bn or e.inWoW) then
        Add(L.FR_WHISPER_CHAR:format(e.character), function() F.Open(e, true) end)
        Add(L.FR_INVITE, function() F.Invite(e) end)
    elseif not e.bn then
        Add(L.FR_WHISPER_CHAR:format(e.name), function() F.Open(e, true) end)
    end
    Add(L.FR_FAVORITE, function()
        F.Favorite(e, not F.Favorite(e))
        FriendsPanel.Refresh()
    end, F.Favorite(e))
    Add(L.FR_WATCH, function() F.Watched(e, not F.Watched(e)) end, F.Watched(e))
    Add(L.FR_NOTE, function()
        local dialog = StaticPopup_Show("SENDIT_FRIEND_NOTE", L.FR_NOTE_PROMPT:format(e.name), nil, e)
        if dialog then dialog.data = e end
    end)
    Add(L.FR_COPY, function()
        local lines = { { e.tag or e.name } }
        if char then lines[#lines + 1] = { char } end
        ns.CopyBox.Show(lines)
    end)
    local conv = Conversation(e)
    if conv then
        if not conv.archived then Add(L.FR_ARCHIVE, function() ns.Whispers.Archive(conv.key) end) end
    end
    Add(L.FR_BLIZZARD, function() F.Menu(e) end)
    Widgets.Menu(items)
    return items
end

local function Matches(e)
    if filter == "" then return true end
    local hay = (e.name .. " " .. (e.character or "") .. " " .. (e.tag or "") .. " " .. (e.area or "")):lower()
    return hay:find(filter, 1, true) ~= nil
end

function FriendsPanel.Refresh()
    if not panel or not panel:IsShown() then return end
    local list, online, total = F.List()
    panel.count:SetText(("(%d/%d)"):format(online, total))
    local y, n = 0, 0
    local function Place(frame, h)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        frame:Show()
        y = y + h
    end
    local offline, shownOffline = {}, 0
    for _, e in ipairs(list) do
        if Matches(e) then
            if e.online or e.favorite then  -- pinned friends stay on top, offline too
                n = n + 1
                rows[n] = rows[n] or NewRow()
                FillRow(rows[n], e)
                Place(rows[n], ROW)
            else
                offline[#offline + 1] = e
            end
        end
    end
    panel.offline = panel.offline or NewSection()
    if #offline > 0 then
        panel.offline.text:SetText((offlineOpen and "- " or "+ ") .. L.FRIENDS_OFFLINE .. " (" .. #offline .. ")")
        Place(panel.offline, SECTION)
        if offlineOpen or filter ~= "" then
            for _, e in ipairs(offline) do
                n = n + 1
                rows[n] = rows[n] or NewRow()
                FillRow(rows[n], e)
                Place(rows[n], ROW)
                shownOffline = shownOffline + 1
            end
        end
    else
        panel.offline:Hide()
    end
    for i = n + 1, #rows do
        rows[i]:Hide()
        rows[i].entry = nil
    end
    content:SetHeight(math.max(1, y))
    emptyText:SetShown(n - shownOffline == 0 and #offline == 0)
end

local function Dock()
    local m = Messenger()
    if not (panel and m) then return end
    local right = (m:GetRight() or 0) + GAP + WIDTH
    local screen = UIParent:GetRight() or math.huge
    panel:ClearAllPoints()
    if right > screen then
        panel:SetPoint("TOPRIGHT", m, "TOPLEFT", -GAP, 0)
        panel:SetPoint("BOTTOMRIGHT", m, "BOTTOMLEFT", -GAP, 0)
    else
        panel:SetPoint("TOPLEFT", m, "TOPRIGHT", GAP, 0)
        panel:SetPoint("BOTTOMLEFT", m, "BOTTOMRIGHT", GAP, 0)
    end
end

local function Build()
    local m = Messenger()
    if not m then return end
    panel = CreateFrame("Frame", "SenditFriendsPanel", m)
    panel:SetWidth(WIDTH)
    panel:EnableMouse(true)
    panel.bg = T.Tex(panel, "BACKGROUND", "bg", ns.db.bgAlpha)
    panel.bg:SetAllPoints()
    T.Border(panel, 1)

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER)
    T.Tex(header, "BACKGROUND", "header", 1, 1):SetAllPoints()
    local title = T.Text(header, 14, "text")
    title:SetPoint("LEFT", 14, 0)
    panel.title = title
    panel.count = T.Text(header, 12, "accent")
    panel.count:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local close = Widgets.IconButton(header, "close", "CLOSE", function() FriendsPanel.Close() end)
    close:SetPoint("RIGHT", -8, 0)

    local search = Widgets.Input(panel, "FRIENDS_SEARCH", 12)
    search:SetPoint("TOPLEFT", 10, -HEADER - 8)
    search:SetPoint("TOPRIGHT", -10, -HEADER - 8)
    search:SetHeight(26)
    search:HookScript("OnTextChanged", function(self)
        filter = strtrim(self:GetText() or ""):lower()
        FriendsPanel.Refresh()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 0, -HEADER - 42)
    scroll:SetPoint("BOTTOMRIGHT", 0, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local range = sf:GetVerticalScrollRange() or 0
        sf:SetVerticalScroll(math.max(0, math.min(range, (sf:GetVerticalScroll() or 0) - delta * ROW)))
    end)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH, 1)
    scroll:SetScrollChild(content)

    emptyText = T.Text(panel, 11, "textMuted")
    emptyText:SetPoint("TOP", scroll, "TOP", 0, -30)
    emptyText:SetJustifyH("CENTER")

    panel.offline = NewSection()
    panel.offline:SetScript("OnClick", function()
        offlineOpen = not offlineOpen
        FriendsPanel.Refresh()
    end)

    -- the messenger can move: re-dock now and then
    local acc = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.5 then return end
        acc = 0
        Dock()
    end)
    panel:SetScript("OnShow", function()
        Dock()
        local list = _G["C_FriendList"]
        if list and list.ShowFriends then pcall(list.ShowFriends) end
        FriendsPanel.Refresh()
    end)
    panel:Hide()
end

local function ApplyTexts()
    if not panel then return end
    panel.title:SetText(L.FRIENDS)
    emptyText:SetText(L.FRIENDS_NONE)
    T.Color(panel.bg, "bg", ns.db.bgAlpha)
end

function FriendsPanel.Sync()
    local m = Messenger()
    local show = Enabled() and Wanted() and m ~= nil and m:IsShown() and not ns.Messenger.IsMinimized()
    if show and not panel then Build() end
    if not panel then return end
    ApplyTexts()
    panel:SetShown(show)
    if show then
        Dock()
        FriendsPanel.Refresh()
    end
    if ns.Messenger.UpdateFriendsButton then ns.Messenger.UpdateFriendsButton() end
end

function FriendsPanel.IsOpen() return panel ~= nil and panel:IsShown() end

function FriendsPanel.Open()
    ns.acct.friendsOpen = true
    FriendsPanel.Sync()
end

function FriendsPanel.Close()
    ns.acct.friendsOpen = false
    FriendsPanel.Sync()
end

function FriendsPanel.Toggle()
    if FriendsPanel.IsOpen() then FriendsPanel.Close() else FriendsPanel.Open() end
end

-- the people icon on the main chat: messenger with the list; a second click folds the list
function FriendsPanel.FromChat()
    local m = Messenger()
    if m and m:IsShown() and FriendsPanel.IsOpen() then
        FriendsPanel.Close()
        return
    end
    ns.acct.friendsOpen = true
    ns.Messenger.Show()
    FriendsPanel.Sync()
end

FriendsPanel.Enabled = Enabled
FriendsPanel._Rows = function() return rows end

-- a watched friend came online: the chat's bubble, a click whispers
local function CameOnline(e)
    if not (ns.WhisperToasts and ns.WhisperToasts.Notice) then return end
    local where = e.inWoW and e.character and (e.character .. (e.area and (" - " .. e.area) or "")) or L.FRIENDS_APP
    ns.WhisperToasts.Notice({
        key = "online:" .. e.key, name = e.name, class = e.class, bn = e.bn,
        text = L.FR_ONLINE_NOW .. "  |cff8a8f9c" .. where .. "|r",
        onClick = function() F.Open(e, ns.db.friendsCharClick) end,
    })
end
FriendsPanel._CameOnline = CameOnline

ns.OnReady(function()
    F.OnChange(FriendsPanel.Refresh)
    F.OnCameOnline(CameOnline)
    ns.OnChanged(function()
        FriendsPanel.Sync()
    end)
end)
