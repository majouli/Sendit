--[[
  Links: everything about hyperlinks in Sendit Chat's own frames.

  Links.Attach(frame)      clickable links + hover tooltips on a frame
  Links.Decorate(text)     plain text -> URLs become clickable (copy box);
                           text inside existing hyperlinks stays untouched
  Links.SetFocusBox(box)   our edit box that has focus (nil = none): a
                           shift-clicked item, spell, quest ... is inserted
                           there, exactly like into the Blizzard chat box

  Clicks: a player name (left click) opens our whisper conversation; every
  other link goes to Blizzard's SetItemRef as in the game's chat (item and
  spell tooltips, shift-click insert, ctrl-click dressing room, player menu).
  A hidden message's "Show Message" (censoredmessage) is shown in place by
  Core/Censored.lua.
  Except the community kinds (clubTicket, clubFinder, community): SetItemRef
  runs Blizzard's link handlers in our (tainted) execution, and a community
  link made Blizzard_Communities create its ticket listener tainted - its
  CLUB_TICKET_RECEIVED handler was then blocked calling the protected
  C_Club.GetLastTicketResponse (ADDON_ACTION_FORBIDDEN, seen in game). Those
  open in the game's own chat only. (Handling items / spells ourselves was
  tried and broke spell links in game: their kind is not always "spell".)
  Insertion hooks Blizzard's InsertLink with hooksecurefunc (post-hook, the
  original runs untouched); our body only writes into our own edit box.
]]
local _, ns = ...
local Safe = ns.Safe

local Links = {}
ns.Links = Links

-- Link kinds that must not go through SetItemRef from addon code (see header).
local COMMUNITY = { clubTicket = true, clubFinder = true, community = true }
Links.COMMUNITY = COMMUNITY

local TOOLTIP_TYPES = {
    item = true, spell = true, enchant = true, quest = true, achievement = true,
    currency = true, talent = true, instancelock = true, mount = true, unit = true,
}

---------------------------------------------------------------------------
-- URLs
---------------------------------------------------------------------------
local URL_COLOR = "|cff7cc4ff"

local function WrapToken(token)
    if token:match("^https?://.") or token:match("^www%.[%w%-]+%.%a") then
        -- Trailing punctuation belongs to the sentence, not the address.
        local url, tail = token:match("^(.-)([%.,;:!%?%)]*)$")
        return URL_COLOR .. "|Hsenditurl:" .. url .. "|h[" .. url .. "]|h|r" .. tail
    end
    return token
end

local function DecoratePlain(piece)
    if not piece:find("http", 1, true) and not piece:find("www.", 1, true) then return piece end
    return (piece:gsub("[^%s|]+", WrapToken))
end

-- fn(piece) -> piece applied only to the text outside hyperlinks.
function Links.MapPlain(text, fn)
    local out, pos = {}, 1
    while true do
        local s = text:find("|H", pos, true)
        local e1 = s and text:find("|h", s + 2, true)
        local e2 = e1 and text:find("|h", e1 + 2, true)
        if not e2 then
            out[#out + 1] = fn(text:sub(pos))
            break
        end
        out[#out + 1] = fn(text:sub(pos, s - 1))
        out[#out + 1] = text:sub(s, e2 + 1)
        pos = e2 + 2
    end
    return table.concat(out)
end

function Links.Decorate(text)
    if not Safe.Str(text) then return text end
    if not text:find("http", 1, true) and not text:find("www.", 1, true) then return text end
    return Links.MapPlain(text, DecoratePlain)
end

-- "[1. Allgemein - Wald von Elwynn]" -> "[1. Allgemein]" (the zone part goes).
function Links.ShortChannels(text)
    if not Safe.Str(text) or not text:find("|Hchannel:", 1, true) then return text end
    return (text:gsub("(|Hchannel:[^|]*|h%[)(%d+)%. ([^%]]-)%]|h", function(pre, num, name)
        local short = name:match("^(.-)%s+%-%s+.+$") or name
        return pre .. num .. ". " .. short .. "]|h"
    end))
end

-- Your name written by someone else (outside links: your own lines carry it
-- only in your player link) -> gold. Returns text, true when found.
function Links.Mention(text, name)
    if not Safe.Str(text) or not name or name == "" or not text:find("|Hplayer:", 1, true) then
        return text, false
    end
    if not text:find(name, 1, true) then return text, false end
    local hit = false
    local pat = "%f[%w]" .. name:gsub("%p", "%%%0") .. "%f[^%w]"
    local out = Links.MapPlain(text, function(piece)
        return (piece:gsub(pat, function(m)
            hit = true
            return "|cffffd100" .. m .. "|r"
        end))
    end)
    return out, hit
end

-- Removes hyperlink and colour markup, keeps the visible text ("[Item]").
function Links.Plain(text)
    if not Safe.Str(text) then return "" end
    return (text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", "")
        :gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "?"))
end

local urlBox
function Links.ShowURL(url)
    local T = ns.Theme
    if not urlBox then
        urlBox = T.Panel(UIParent, "DIALOG")
        urlBox:SetSize(420, 64)
        urlBox:SetPoint("CENTER", 0, 160)
        T.Decorate(urlBox, "panel")
        local hint = T.Text(urlBox, 11, "textMuted")
        hint:SetPoint("TOPLEFT", 12, -10)
        hint:SetText(ns.L.URL_COPY)
        local eb = CreateFrame("EditBox", nil, urlBox)
        eb:SetPoint("TOPLEFT", 12, -28)
        eb:SetPoint("BOTTOMRIGHT", -12, 10)
        T.SetFont(eb, 13)
        eb:SetAutoFocus(false)
        local function Close() urlBox:Hide() end
        eb:SetScript("OnEscapePressed", Close)
        eb:SetScript("OnEnterPressed", Close)
        eb:SetScript("OnEditFocusLost", Close)
        eb:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(urlBox.url); self:HighlightText() end
        end)
        urlBox.eb = eb
    end
    urlBox.url = url
    urlBox:Show()
    urlBox.eb:SetText(url)
    urlBox.eb:SetFocus()
    urlBox.eb:HighlightText()
end

---------------------------------------------------------------------------
-- Click and hover
---------------------------------------------------------------------------
local function NoModifier()
    return not (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown())
end

function Links.Click(_, link, text, button)
    local plain = Safe.Str(link)
    if plain then
        local kind, rest = plain:match("^([^:]+):(.*)$")
        if kind == "senditurl" then
            Links.ShowURL(rest)
            return
        end
        if kind == "censoredmessage" then  -- Core/Censored.lua: shown in place, never via SetItemRef
            ns.Censored.Show(rest)
            return
        end
        if kind == "player" and button == "LeftButton" and NoModifier() and ns.OpenWhisper then
            local name = rest:match("^([^:]+)")
            if name and name ~= "" then
                ns.OpenWhisper(name)
                return
            end
        end
    end
    local kind = plain and plain:match("^([^:]+)")
    if kind and COMMUNITY[kind] then return end
    local SetItemRef = _G["SetItemRef"]
    if SetItemRef then pcall(SetItemRef, link, text, button, _G["DEFAULT_CHAT_FRAME"]) end
end

function Links.Enter(frame, link)
    local plain = Safe.Str(link)
    local kind = plain and plain:match("^([^:]+)")
    if kind and COMMUNITY[kind] then
        -- often dressed up as a spell or item ("[Mark of the Pack Leader]")
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        GameTooltip:SetText(ns.L.LINK_COMMUNITY, 1, 0.82, 0)
        GameTooltip:AddLine(ns.L.LINK_COMMUNITY_DESC, 1, 1, 1, true)
        GameTooltip:Show()
        return
    end
    if not kind or not TOOLTIP_TYPES[kind] then return end
    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    if not pcall(GameTooltip.SetHyperlink, GameTooltip, plain) then GameTooltip:Hide() return end
    GameTooltip:Show()
end

function Links.Leave()
    GameTooltip:Hide()
end

function Links.Attach(frame)
    frame:EnableMouse(true)  -- link clicks need a mouse-enabled frame
    frame:SetHyperlinksEnabled(true)
    frame:SetScript("OnHyperlinkClick", Links.Click)
    frame:SetScript("OnHyperlinkEnter", Links.Enter)
    frame:SetScript("OnHyperlinkLeave", Links.Leave)
end

---------------------------------------------------------------------------
-- Shift-click insertion into our edit boxes
---------------------------------------------------------------------------
local focusBox
function Links.SetFocusBox(box) focusBox = box end
function Links.FocusBox() return focusBox end

local lastText, lastTime
local function OnInsert(text)
    if not focusBox or not focusBox:HasFocus() then return end
    local plain = Safe.Str(text)
    if not plain or plain == "" then return end
    -- The global alias and ChatFrameUtil.InsertLink may both be hooked and
    -- one may call the other: insert once per click.
    local now = GetTime()
    if plain == lastText and lastTime == now then return end
    lastText, lastTime = plain, now
    focusBox:Insert(plain)
    -- With no Blizzard chat box active, InsertLink reports "not inserted" and
    -- a shift-clicked bag stack also opens the split-stack frame. The click
    -- went into our box, so that frame is closed right after.
    C_Timer.After(0, function()
        local split = _G["StackSplitFrame"]
        if split and split:IsShown() then pcall(split.Hide, split) end
    end)
end
Links._OnInsert = OnInsert

local util = _G["ChatFrameUtil"]
if type(util) == "table" and type(util.InsertLink) == "function" then
    hooksecurefunc(util, "InsertLink", OnInsert)
end
if type(_G["ChatEdit_InsertLink"]) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", OnInsert)
end
