--[[
  Links: hyperlinks in Sendit Chat's own frames.
  Links.Attach(frame) clickable links + tooltips;  Links.Decorate(text) URLs clickable (copy box)
  Links.SetFocusBox(box) shift-clicked links go into our focused box
  A player name opens our conversation; other links go to Blizzard's SetItemRef - except community
  links (clubTicket, clubFinder, community): run from addon code they taint Blizzard_Communities
  (ADDON_ACTION_FORBIDDEN). Censored messages: Core/Censored.lua. InsertLink is post-hooked only.
  Shift-clicked addon links (kinds the client cannot send: "Invalid escape code") go in as plain text.
]]
local _, ns = ...
local Safe = ns.Safe

local Links = {}
ns.Links = Links

-- link kinds that must not go through SetItemRef from addon code
local COMMUNITY = { clubTicket = true, clubFinder = true, community = true }
Links.COMMUNITY = COMMUNITY

local TOOLTIP_TYPES = {
    item = true, spell = true, enchant = true, quest = true, achievement = true,
    currency = true, talent = true, instancelock = true, mount = true, unit = true,
}

-- link kinds the client sends; any other kind is an addon's own link
local CHAT_LINKS = {
    player = true, BNplayer = true, playerCommunity = true, channel = true, trade = true, journal = true,
    battlepet = true, transmogappearance = true, transmogillusion = true, outfit = true, worldmap = true,
    keystone = true, calendarEvent = true, dungeonScore = true,
}
for kind in pairs(TOOLTIP_TYPES) do CHAT_LINKS[kind] = true end

-- the words a link shows, without colour, link and texture codes
local function Visible(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
        :gsub("|H.-|h", ""):gsub("|h", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end
Links._Visible = Visible

-- URLs
local URL_COLOR = "|cff7cc4ff"

local function WrapToken(token)
    if token:match("^https?://.") or token:match("^www%.[%w%-]+%.%a") then
        -- trailing punctuation belongs to the sentence
        local url, tail = token:match("^(.-)([%.,;:!%?%)]*)$")
        return URL_COLOR .. "|Hsenditurl:" .. url .. "|h[" .. url .. "]|h|r" .. tail
    end
    return token
end

local function DecoratePlain(piece)
    if not piece:find("http", 1, true) and not piece:find("www.", 1, true) then return piece end
    return (piece:gsub("[^%s|]+", WrapToken))
end

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

-- "[1. General - Elwynn Forest]" -> "[1. General]"
function Links.ShortChannels(text)
    if not Safe.Str(text) or not text:find("|Hchannel:", 1, true) then return text end
    return (text:gsub("(|Hchannel:[^|]*|h%[)(%d+)%. ([^%]]-)%]|h", function(pre, num, name)
        local short = name:match("^(.-)%s+%-%s+.+$") or name
        return pre .. num .. ". " .. short .. "]|h"
    end))
end

-- your name in someone else's text (outside links) -> gold; returns text, found
function Links.Mention(text, name)
    if not Safe.Str(text) or not name or name == "" or not text:find("|Hplayer:", 1, true) then
        return text, false
    end
    if not text:find(name, 1, true) then return text, false end
    local hit = false
    -- bytes from 128 on are letters too (Cyrillic and accented names are UTF-8)
    local pat = "%f[%w\128-\255]" .. name:gsub("%p", "%%%0") .. "%f[^%w\128-\255]"
    local out = Links.MapPlain(text, function(piece)
        return (piece:gsub(pat, function(m)
            hit = true
            return "|cffffd100" .. m .. "|r"
        end))
    end)
    return out, hit
end

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

local focusBox  -- our own input box with focus gets shift-clicked links

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
        if kind == "censoredmessage" then  -- shown in place, never via SetItemRef
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
    if kind and not CHAT_LINKS[kind] and IsModifiedClick("CHATLINK") then
        local words = Visible(Safe.Str(text) or "")
        if words == "" then return end
        if focusBox and focusBox:HasFocus() then
            focusBox:Insert(words)
        else
            local util = _G["ChatFrameUtil"]
            local insert = (type(util) == "table" and util.InsertLink) or _G["ChatEdit_InsertLink"]
            if insert then pcall(insert, words) end
        end
        return
    end
    local SetItemRef = _G["SetItemRef"]
    if SetItemRef then pcall(SetItemRef, link, text, button, _G["DEFAULT_CHAT_FRAME"]) end
end

function Links.Enter(frame, link)
    local plain = Safe.Str(link)
    local kind = plain and plain:match("^([^:]+)")
    if kind and COMMUNITY[kind] then
        -- often dressed up as a spell or item
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
    frame:EnableMouse(true)
    frame:SetHyperlinksEnabled(true)
    frame:SetScript("OnHyperlinkClick", Links.Click)
    frame:SetScript("OnHyperlinkEnter", Links.Enter)
    frame:SetScript("OnHyperlinkLeave", Links.Leave)
end

function Links.SetFocusBox(box) focusBox = box end
function Links.FocusBox() return focusBox end

local lastText, lastTime
local function OnInsert(text)
    if not focusBox or not focusBox:HasFocus() then return end
    local plain = Safe.Str(text)
    if not plain or plain == "" then return end
    -- the global alias and ChatFrameUtil.InsertLink may call each other: insert once
    local now = GetTime()
    if plain == lastText and lastTime == now then return end
    lastText, lastTime = plain, now
    focusBox:Insert(plain)
    -- no Blizzard box active: a shift-clicked stack also opens the split frame - closed again
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
