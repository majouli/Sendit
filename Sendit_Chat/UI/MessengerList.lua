--[[
  MessengerList: the messenger's left column - "Name to whisper" field (NameComplete), tabs Chats |
  Archive, one row per partner (avatar, name, time, preview, unread badge; archive: archived / delete
  dates). Left click shows, middle click archives / restores, right click menu (add friend, pin, archive,
  delete). List.Build(parent, width) / Refresh() / View() / SetView(view) / ViewOf(conv) / First() / Holds(conv)
]]
local _, ns = ...
local T, Widgets, Links, W = ns.Theme, ns.Widgets, ns.Links, ns.Whispers
local L = ns.L

local List = {}
ns.MessengerList = List

local ROW = 52
local TOP = 68  -- field + tabs above the list

local column, content, emptyText
local rows = {}
local view = "chats"

local function TimeLabel(t)
    local now = time()
    if date("%Y%m%d", t) == date("%Y%m%d", now) then return date("%H:%M", t) end
    if date("%Y%m%d", t) == date("%Y%m%d", now - 86400) then return L.YESTERDAY end
    return date("%d.%m.", t)
end
List._TimeLabel = TimeLabel

local function Preview(c)
    local m = c.msgs[#c.msgs]
    if not m then return "" end
    local text = Links.Plain(m.m):gsub("[\r\n]+", " ")
    if m.o then return L.YOU .. ": " .. text end
    return text
end
List._Preview = Preview

local function ArchiveNote(c)
    local days = math.floor(W.ArchiveLeft(c) / 86400)
    if days < 1 then return L.ARCHIVE_TODAY end
    return L.ARCHIVE_LEFT:format(days)
end

local function Hex(role)
    local r, g, b = T.RGB(role)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

-- Battle.net friend or character (with realm)
local function NameLine(c)
    local tag = c.bn and (" " .. Hex("bn") .. L.BATTLENET .. "|r") or (" |cff8a8f9c- " .. W.RealmOf(c) .. "|r")
    return (c.name or "?") .. tag
end

function List.View() return view end
function List.ViewOf(conv) return conv and conv.archived and "archive" or "chats" end

function List.SetView(v)
    view = v
    List.Refresh()
end

local function Items()
    return view == "archive" and W.Archived() or W.List()
end

function List.First() return Items()[1] end

function List.Holds(conv)
    return conv ~= nil and W.Get(conv.key) ~= nil and List.ViewOf(conv) == view
end

local function AskDelete(c)
    StaticPopup_Show("SENDIT_DELETE_CHAT", c.name or "?", nil, c.key)
end

local function RowMenu(c)
    if c.archived then
        Widgets.Menu({
            { L.RESTORE_CHAT, function() W.Restore(c.key) end },
            { L.DELETE_FOREVER, function() AskDelete(c) end },
        })
    else
        local items = {}
        local F = ns.Friends
        if not c.bn and c.target and F and not F.IsFriend(c.target) then
            items[#items + 1] = { L.FR_ADD, function() F.Add(c.target) end }
        end
        items[#items + 1] = { L.FR_FAVORITE, function() W.Favorite(c.key, not W.Favorite(c.key)) end, W.Favorite(c.key) }
        items[#items + 1] = { L.ARCHIVE_CHAT, function() W.Archive(c.key) end }
        Widgets.Menu(items)
        return items
    end
end

local function OnRowClick(row, button)
    local c = row.conv
    if not c then return end
    if button == "MiddleButton" then
        if c.archived then W.Restore(c.key) else W.Archive(c.key) end
    elseif button == "RightButton" then
        RowMenu(c)
    else
        ns.Messenger.Open(c, true)
    end
end

local function Highlight(row)
    local shown = row.conv ~= nil and row.conv == ns.Conversation.Current()
    T.Color(row.hl, "ink", shown and 0.10 or 0)
    return shown
end

local function NewRow()
    local r = CreateFrame("Button", nil, content)
    r:SetHeight(ROW)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    r.hl = T.Tex(r, "BACKGROUND", "ink", 0)
    r.hl:SetAllPoints()
    -- pinned: the accent bar, as in the friends list; inset, the window's frame covers the edge
    r.pin = T.Tex(r, "BORDER", "accent", 1)
    T.Own(r.pin)
    r.pin:SetPoint("TOPLEFT", 5, 0); r.pin:SetPoint("BOTTOMLEFT", 5, 0); r.pin:SetWidth(2)
    r.avatar = T.Avatar(r, 34)
    r.avatar:SetPoint("LEFT", 10, 0)
    r.name = T.Text(r, 12, "text")
    T.Own(r.name)
    r.name:SetPoint("TOPLEFT", r.avatar, "TOPRIGHT", 10, -2)
    r.name:SetPoint("RIGHT", r, "RIGHT", -52, 0)
    r.name:SetWordWrap(false)
    r.time = T.Text(r, 10, "textMuted")
    r.time:SetPoint("TOPRIGHT", -10, -10)
    r.time:SetJustifyH("RIGHT")
    r.preview = T.Text(r, 11, "textDim", "OVERLAY", true)
    r.preview:SetPoint("BOTTOMLEFT", r.avatar, "BOTTOMRIGHT", 10, 2)
    r.preview:SetPoint("RIGHT", r, "RIGHT", -36, 0)
    r.preview:SetWordWrap(false)
    r.badge = Widgets.Badge(r)
    r.badge:SetPoint("BOTTOMRIGHT", -10, 10)
    local line = T.Tex(r, "BORDER", "ink", 0.06)
    line:SetPoint("BOTTOMLEFT", 54, 0); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    r:SetScript("OnEnter", function(self) T.Color(self.hl, "ink", 0.06) end)
    r:SetScript("OnLeave", Highlight)
    r:SetScript("OnClick", OnRowClick)
    return r
end

local function FillRow(r, c, archive)
    r.conv = c
    r.avatar:Set(c.name, c.class)
    r.name:SetText(NameLine(c))
    local cr, cg, cb = T.ClassRGB(c.class)
    if c.bn then cr, cg, cb = T.RGB("bn") end
    r.name:SetTextColor(cr, cg, cb, 1)
    r.pin:SetShown(c.favorite == true and not archive)
    r.pin:SetVertexColor(T.RGB("accent"))
    if archive then
        r.time:SetText(TimeLabel(c.archived))
        r.preview:SetText(ArchiveNote(c))
        r.badge:Set(0)
        T.Color(r.preview, "textMuted")
    else
        local unread = c.unread or 0
        r.time:SetText(c.msgs[#c.msgs] and TimeLabel(c.last or time()) or "")
        r.preview:SetText(Preview(c))
        r.badge:Set(unread)
        T.Color(r.preview, unread > 0 and "text" or "textDim")
    end
    Highlight(r)
end

local function NewTab(key, index, width)
    local tab = CreateFrame("Button", nil, column)
    tab:SetSize(width, 22)
    tab:SetPoint("TOPLEFT", 10 + (index - 1) * width, -40)
    tab.label = T.Text(tab, 11, "textDim")
    tab.label:SetPoint("CENTER", 0, 1)
    tab.line = T.Tex(tab, "ARTWORK", "accent", 1)
    tab.line:SetPoint("BOTTOMLEFT"); tab.line:SetPoint("BOTTOMRIGHT"); tab.line:SetHeight(2)
    local base = T.Tex(tab, "BORDER", "ink", 0.08)
    base:SetPoint("BOTTOMLEFT"); base:SetPoint("BOTTOMRIGHT"); base:SetHeight(1)
    function tab.SetSelected(self, on)
        self.line:SetShown(on)
        T.Color(self.label, on and "text" or "textDim")
    end
    tab:SetScript("OnClick", function() List.SetView(key) end)
    return tab
end

local function RefreshTabs()
    local archived = #W.Archived()
    List.tabs.chats.label:SetText(L.TAB_CHATS)
    List.tabs.archive.label:SetText(archived > 0 and (L.TAB_ARCHIVE .. " (" .. archived .. ")") or L.TAB_ARCHIVE)
    List.tabs.chats:SetSelected(view == "chats")
    List.tabs.archive:SetSelected(view == "archive")
end

local function NewChatField()
    local field = Widgets.Input(column, "NEW_CHAT", 12)
    field:SetPoint("TOPLEFT", 10, -8)
    field:SetPoint("TOPRIGHT", -10, -8)
    field:SetHeight(26)
    ns.NameComplete.Attach(field, ns.OpenWhisper)
    local plus = Widgets.IconButton(field, "plus", nil, function()
        local name = field:GetText()
        field:SetText("")
        if name and strtrim(name) ~= "" then ns.OpenWhisper(name) else field:SetFocus() end
    end)
    plus:SetPoint("RIGHT", -2, 0)
    return field
end

local function NewScroll(width)
    local scroll = CreateFrame("ScrollFrame", nil, column)
    scroll:SetPoint("TOPLEFT", 0, -TOP)
    scroll:SetPoint("BOTTOMRIGHT", 0, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local range = sf:GetVerticalScrollRange() or 0
        local v = (sf:GetVerticalScroll() or 0) - delta * ROW
        sf:SetVerticalScroll(math.max(0, math.min(range, v)))
    end)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)
    return scroll
end

function List.Build(parent, width)
    column = CreateFrame("Frame", nil, parent)
    column:SetWidth(width)
    column.bg = T.Tex(column, "BACKGROUND", "header", 0.35, 1)
    column.bg:SetAllPoints()

    NewChatField()
    local tabWidth = (width - 20) / 2
    List.tabs = { chats = NewTab("chats", 1, tabWidth), archive = NewTab("archive", 2, tabWidth) }
    local scroll = NewScroll(width)

    emptyText = T.Text(column, 11, "textMuted")
    emptyText:SetPoint("TOP", scroll, "TOP", 0, -40)
    emptyText:SetJustifyH("CENTER")

    StaticPopupDialogs["SENDIT_DELETE_CHAT"] = {
        text = L.DELETE_CONFIRM, button1 = YES, button2 = NO,
        OnAccept = function(_, key) W.Delete(key) end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    return column
end

function List.Refresh()
    if not column then return end
    local items = Items()
    local archive = view == "archive"
    for i, c in ipairs(items) do
        local r = rows[i] or NewRow()
        rows[i] = r
        FillRow(r, c, archive)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW)
        r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW)
        r:Show()
    end
    for i = #items + 1, #rows do
        rows[i]:Hide()
        rows[i].conv = nil
    end
    content:SetHeight(math.max(1, #items * ROW))
    emptyText:SetText(archive and L.NO_ARCHIVE or L.NO_CHATS)
    emptyText:SetShown(#items == 0)
    RefreshTabs()
end

List._Rows = function() return rows end
List._RowMenu = RowMenu
