--[[
  Friends: the friends list as the friends panel shows it (UI/FriendsPanel.lua).

  Sources: Battle.net friends (C_BattleNet.GetFriendAccountInfo, BNGetNumFriends)
  and character friends (C_FriendList.GetFriendInfoByIndex). Every read goes
  through Safe (secret / missing values become nil), so a client without one of
  the APIs just lists fewer friends.

  Friends.List() -> entries, online, total; entries sorted: in World of Warcraft
  first, then online elsewhere (Blizzard App), then offline; by name within.
    entry = { key, bn, name (BattleTag first part or character), tag, accountName
              (Battle.net token, session only), character, realm, level, class (file
              token), area, client ("WoW" | "App" | ...), online, afk, dnd, note }
  Friends.Open(entry, viaCharacter)  the messenger on that friend: Battle.net,
                        or (viaCharacter, Battle.net friend in WoW) the character
  Friends.CharacterName(entry)  "Name-Realm" to whisper / invite, or nil
  Friends.Invite(entry)  group invite to the character
  Friends.SetNote(entry, text)
  Friends.Favorite(entry [, on]) / Friends.Watched(entry [, on])  pinned to
                        the top / a notice when they come online (account-wide,
                        ns.acct.friendFavorites / friendWatch, by key)
  Friends.OnCameOnline(fn)  fn(entry) for a watched friend going online
  Friends.Menu(entry)   Blizzard's player menu (invite, note, remove, ...)
  Friends.OnChange(fn)  after the client's friend events (throttled to one per frame)
]]
local _, ns = ...
local Safe = ns.Safe

local Friends = {}
ns.Friends = Friends

local listeners, onlineListeners = {}, {}
function Friends.OnChange(fn) listeners[#listeners + 1] = fn end
function Friends.OnCameOnline(fn) onlineListeners[#onlineListeners + 1] = fn end

local function Marks(field)
    if not ns.acct then return {} end
    ns.acct[field] = ns.acct[field] or {}
    return ns.acct[field]
end

-- getter without `on`, setter with it
local function Mark(field, e, on)
    local marks = Marks(field)
    if on == nil then return marks[e.key] == true end
    marks[e.key] = on and true or nil
    return on
end
function Friends.Favorite(e, on) return Mark("friendFavorites", e, on) end
function Friends.Watched(e, on) return Mark("friendWatch", e, on) end

-- Localized class name -> class file token (RAID_CLASS_COLORS key).
local classTokens
local function ClassToken(localized)
    localized = Safe.Str(localized)
    if not localized then return nil end
    if not classTokens then
        classTokens = {}
        for _, t in ipairs({ "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE" }) do
            local names = _G[t]
            if type(names) == "table" then
                for token, name in pairs(names) do classTokens[name] = token end
            end
        end
    end
    return classTokens[localized] or (_G["RAID_CLASS_COLORS"] and _G["RAID_CLASS_COLORS"][localized:upper()] and localized:upper())
end

local function Bool(v)
    v = Safe.Call(function() return v == true end)
    return v == true
end

local function BattleNet(out)
    local bn, num = _G["C_BattleNet"], _G["BNGetNumFriends"]
    if not (bn and bn.GetFriendAccountInfo and num) then return end
    for i = 1, Safe.Num(Safe.Call(num)) or 0 do
        local info = Safe.Call(bn.GetFriendAccountInfo, i)
        if type(info) == "table" then
            local tag = Safe.Str(info.battleTag)
            local game = type(info.gameAccountInfo) == "table" and info.gameAccountInfo or {}
            local online = Bool(game.isOnline)
            local client = Safe.Str(game.clientProgram)
            local character = Safe.Str(game.characterName)
            if character == "" then character = nil end
            out[#out + 1] = {
                key = "bn:" .. (tag or tostring(i)), bn = true, bnID = Safe.Num(info.bnetAccountID),
                name = tag and tag:match("^([^#]+)") or Safe.Str(info.accountName) or "?",
                tag = tag, accountName = Safe.Str(info.accountName),
                character = character, realm = Safe.Str(game.realmName),
                level = Safe.Num(game.characterLevel), class = ClassToken(game.className),
                area = Safe.Str(game.areaName), rich = Safe.Str(game.richPresence),
                client = client, online = online, afk = Bool(info.isAFK) or Bool(game.isGameAFK),
                dnd = Bool(info.isDND) or Bool(game.isGameBusy), note = Safe.Str(info.note),
                inWoW = online and character ~= nil and (client == nil or client:find("^WoW") ~= nil),
            }
        end
    end
end

local function Characters(out)
    local list = _G["C_FriendList"]
    if not (list and list.GetNumFriends and list.GetFriendInfoByIndex) then return end
    for i = 1, Safe.Num(Safe.Call(list.GetNumFriends)) or 0 do
        local info = Safe.Call(list.GetFriendInfoByIndex, i)
        local name = type(info) == "table" and Safe.Str(info.name)
        if name then
            local online = Bool(info.connected)
            out[#out + 1] = {
                key = "p:" .. name:lower(), bn = false, name = name:gsub("%-.*$", ""),
                character = name, level = Safe.Num(info.level), class = ClassToken(info.className),
                area = Safe.Str(info.area), online = online, afk = Bool(info.afk), dnd = Bool(info.dnd),
                note = Safe.Str(info.notes), inWoW = online,
            }
        end
    end
end

-- Pinned friends first (online before offline), then in WoW, elsewhere, offline.
local function Rank(e)
    if e.favorite then return e.online and 0 or 0.5 end
    if e.inWoW then return 1 end
    if e.online then return 2 end
    return 3
end

function Friends.List()
    local out = {}
    BattleNet(out)
    Characters(out)
    local online = 0
    for _, e in ipairs(out) do
        if e.online then online = online + 1 end
        e.favorite = Friends.Favorite(e)
    end
    table.sort(out, function(a, b)
        local ra, rb = Rank(a), Rank(b)
        if ra ~= rb then return ra < rb end
        return a.name:lower() < b.name:lower()
    end)
    return out, online, #out
end

-- "Name-Realm" of the character (realm without spaces, like the client wants it).
-- Realm as the client writes it in names: no spaces, dashes or apostrophes.
local function NormalRealm(realm)
    return (tostring(realm or ""):gsub("[%s%-']", ""))
end

local function OwnRealm()
    return NormalRealm(Safe.Str(Safe.Call(_G["GetNormalizedRealmName"])) or Safe.Str(Safe.Call(_G["GetRealmName"])))
end

-- The name to whisper / invite. Forever names can carry a surname ("Adamned
-- Sendit"); the realm is added only for another realm (seen in game: whispers
-- to "Name Surname-Realm" on the own realm found nobody).
function Friends.CharacterName(e)
    if not (e and e.character and e.online) then return nil end
    if not e.bn or not e.realm or e.realm == "" then return e.character end
    local realm = NormalRealm(e.realm)
    if realm == "" or realm:lower() == OwnRealm():lower() then return e.character end
    return e.character .. "-" .. realm
end

-- A typed first name -> the full name of the one friend or conversation it
-- fits ("Adamned" -> "Adamned Sendit"); anything else stays as typed.
function Friends.Resolve(name)
    name = name and strtrim(name) or ""
    if name == "" or name:find("[%s%-]") then return name end
    local want, found = name:lower(), {}
    local function Try(full)
        if type(full) == "string" and full:lower():match("^([^%s%-]+)") == want then found[full] = true end
    end
    for _, e in ipairs(Friends.List()) do
        if e.online then Try(Friends.CharacterName(e)) end
    end
    for _, c in ipairs(ns.Whispers.List()) do
        if not c.bn then Try(c.target) end
    end
    local one, n = nil, 0
    for full in pairs(found) do one, n = full, n + 1 end
    return n == 1 and one or name
end

function Friends.Open(e, viaCharacter)
    if not e then return end
    local conv
    local char = Friends.CharacterName(e)
    if e.bn and not (viaCharacter and e.inWoW and char) then
        conv = e.accountName and ns.Whispers.OpenBN(e.accountName)
    else
        conv = ns.Whispers.Open(char or e.character)
    end
    if conv and ns.Messenger then ns.Messenger.Open(conv, true) end
end

function Friends.Invite(e)
    local name = Friends.CharacterName(e)
    if not name then return end
    local party = _G["C_PartyInfo"]
    local invite = (party and party.InviteUnit) or _G["InviteUnit"]
    if invite then pcall(invite, name) end
end

-- Is this character (a conversation's target) already a friend - as a
-- character friend or as a Battle.net friend's character?
function Friends.IsFriend(name)
    name = name and name:lower()
    if not name then return false end
    local first = name:match("^([^%-]+)")
    for _, e in ipairs(Friends.List()) do
        local char = e.character and e.character:lower()
        if char and (char == name or char == first or (Friends.CharacterName(e) or ""):lower() == name) then
            return true
        end
    end
    return false
end

-- Add a friend: C_FriendList.AddFriend has restrictions (client API docs:
-- HasRestrictions) - called from addon code it does nothing (seen in game).
-- So Blizzard's own "Add Friend" window opens with the name filled in; its
-- Accept runs Blizzard's code (for a plain character name it reads nothing we
-- wrote), the player confirms with Enter. The list refreshes on FRIENDLIST_UPDATE.
function Friends.Add(name)
    if not name or name == "" then return false end
    if not _G["AddFriendFrame"] then
        local addons = _G["C_AddOns"]
        if addons and addons.LoadAddOn then pcall(addons.LoadAddOn, "Blizzard_AddFriend") end
    end
    local frame, box = _G["AddFriendFrame"], _G["AddFriendNameEditBox"]
    local init, show = _G["AddFriendEntryFrame_Init"], _G["StaticPopupSpecial_Show"]
    if not (frame and box and show) then return false end
    if init then pcall(init, true) end
    pcall(show, frame)
    if frame.ShowEntry then pcall(frame.ShowEntry, frame) end
    box:SetText(name)
    box:SetFocus()
    box:HighlightText()
    return true
end

function Friends.SetNote(e, text)
    if not e then return end
    text = text or ""
    if e.bn then
        local set = _G["BNSetFriendNote"]
        if set and e.bnID then pcall(set, e.bnID, text) end
    else
        local list = _G["C_FriendList"]
        if list and list.SetFriendNotes then pcall(list.SetFriendNotes, e.character, text) end
    end
end

function Friends.Menu(e)
    if not e then return end
    local link
    if e.bn then
        local bnID
        local bn = _G["C_BattleNet"]
        if e.accountName and bn and bn.GetFriendAccountInfo then
            for i = 1, Safe.Num(Safe.Call(_G["BNGetNumFriends"])) or 0 do
                local info = Safe.Call(bn.GetFriendAccountInfo, i)
                if type(info) == "table" and Safe.Str(info.accountName) == e.accountName then
                    bnID = Safe.Num(info.bnetAccountID)
                end
            end
        end
        if bnID then link = ("BNplayer:%s:%d:0:BN_WHISPER:%s"):format(e.accountName, bnID, e.accountName) end
    elseif e.character then
        link = "player:" .. e.character
    end
    local setRef = _G["SetItemRef"]
    if link and setRef then pcall(setRef, link, "[" .. e.name .. "]", "RightButton", _G["DEFAULT_CHAT_FRAME"]) end
end

-- Watched friends going online: compared with the last list (the first
-- list after login only sets the baseline).
local wasOnline
local function CheckOnline()
    local list = Friends.List()
    local now = {}
    for _, e in ipairs(list) do
        now[e.key] = e.online
        if wasOnline and e.online and not wasOnline[e.key] and Friends.Watched(e) then
            for _, fn in ipairs(onlineListeners) do pcall(fn, e) end
        end
    end
    wasOnline = now
end

-- The client's friend events, at most one refresh per frame.
local pending = false
local function Changed()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        CheckOnline()
        for _, fn in ipairs(listeners) do pcall(fn) end
    end)
end
Friends._Changed = Changed

ns.OnReady(function()
    for _, event in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE",
                             "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED", "BN_DISCONNECTED",
                             "BN_FRIEND_LIST_SIZE_CHANGED" }) do
        pcall(ns.Listen, event, Changed)
    end
    local list = _G["C_FriendList"]
    if list and list.ShowFriends then pcall(list.ShowFriends) end  -- ask the server for a fresh list
end)
