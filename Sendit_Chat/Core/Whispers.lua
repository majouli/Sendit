--[[
  Whispers: the messenger's data - one conversation per partner, per character (ns.char.convs).
  conversation = { key, name, target, bn, class, realm, kname, unread, last, archived, favorite, msgs }
  W.List() (pinned first) / Archived() / Archive(key) / Restore(key) (archived ones go after ARCHIVE_DAYS)
  W.Favorite(key [, on]) - pinned: listed first, so kept when old chats are trimmed
  W.Get(key) / Open(name) / Send(conv, text) -> ok, reason / Split(text, max) (never cuts a link)
  W.MarkRead(conv) / Delete(key) / OnChange(fn) / UnreadChats() / RealmOf(conv) / BNGame(conv)
  W.viewing = fn(key) set by the UI. Secret texts or senders (lockdown) are skipped.
]]
local _, ns = ...
local Safe = ns.Safe

local W = {}
ns.Whispers = W

local MAX_MSGS = 200
local MAX_CONVS = 80
local MAX_BYTES = 255
local ARCHIVE_DAYS = 30
W.ARCHIVE_DAYS = ARCHIVE_DAYS

local listeners = {}
function W.OnChange(fn) listeners[#listeners + 1] = fn end
local function Notify(conv, msg, incoming)
    for i = 1, #listeners do listeners[i](conv, msg, incoming) end
end

local function Convs() return ns.char and ns.char.convs or {} end

function W.Get(key) return Convs()[key] end

function W.List()
    local list = {}
    for _, c in pairs(Convs()) do if not c.archived then list[#list + 1] = c end end
    table.sort(list, function(a, b)
        if (a.favorite == true) ~= (b.favorite == true) then return a.favorite == true end
        if a.last ~= b.last then return (a.last or 0) > (b.last or 0) end
        return a.key < b.key
    end)
    return list
end

function W.Favorite(key, on)
    local c = Convs()[key]
    if not c then return false end
    if on == nil then return c.favorite == true end
    c.favorite = on or nil
    Notify(c, nil, false)
    return on
end

-- seconds until an archived conversation is deleted
function W.ArchiveLeft(conv, now)
    return (conv.archived or 0) + ARCHIVE_DAYS * 86400 - (now or time())
end

function W.Purge(now)
    now = now or time()
    for key, c in pairs(Convs()) do
        if c.archived and W.ArchiveLeft(c, now) <= 0 then Convs()[key] = nil end
    end
end

function W.Archived()
    W.Purge()
    local list = {}
    for _, c in pairs(Convs()) do if c.archived then list[#list + 1] = c end end
    table.sort(list, function(a, b)
        if a.archived ~= b.archived then return a.archived > b.archived end
        return a.key < b.key
    end)
    return list
end

function W.Unread()
    local n = 0
    for _, c in pairs(Convs()) do n = n + (c.unread or 0) end
    return n
end

function W.UnreadChats()
    local n = 0
    for _, c in pairs(Convs()) do if (c.unread or 0) > 0 then n = n + 1 end end
    return n
end

local function OwnRealm()
    return Safe.Str(Safe.Call(_G["GetRealmName"])) or Safe.Str(Safe.Call(_G["GetNormalizedRealmName"])) or "?"
end

function W.RealmOf(conv)
    return conv.realm or OwnRealm()
end

local function RealmPart(full)
    local realm = full:match("%-(.+)$")
    return realm or OwnRealm()
end

local function Short(full)
    local amb = _G["Ambiguate"]
    if amb then
        local ok, s = pcall(amb, full, "short")
        if ok and Safe.Str(s) then return s end
    end
    return (full:gsub("%-.*$", ""))
end

local function PlayerKey(full)
    local name, realm = full:match("^([^%-]+)%-?(.*)$")
    local own = Safe.Str(Safe.Call(_G["GetNormalizedRealmName"])) or ""
    if realm == "" or realm == own then return "p:" .. name:lower() end
    return "p:" .. (name .. "-" .. realm):lower()
end

-- the name to type for a whisper: a BattleTag, a name, or Name-Realm off the own realm
function W.PlainName(conv)
    local full = conv.target or conv.name or "?"
    if conv.bn then return full end
    local name, realm = full:match("^([^%-]+)%-?(.*)$")
    local own = Safe.Str(Safe.Call(_G["GetNormalizedRealmName"])) or ""
    if not name or realm == "" or realm == own then return name or full end
    return full
end

local function ClassOf(guid)
    guid = Safe.Str(guid)
    local fn = _G["GetPlayerInfoByGUID"]
    if not guid or guid == "" or not fn then return nil end
    local ok, _, class = pcall(fn, guid)
    return ok and Safe.Str(class) or nil
end

local function Trim(conv)
    local msgs = conv.msgs
    while #msgs > MAX_MSGS do table.remove(msgs, 1) end
end

local function TrimConvs()
    local list = W.List()
    for i = MAX_CONVS + 1, #list do Convs()[list[i].key] = nil end
end

local function Ensure(key, fields)
    local all = Convs()
    local c = all[key]
    if not c then
        c = { key = key, msgs = {}, unread = 0, last = time() }
        all[key] = c
    end
    for k, v in pairs(fields) do if v ~= nil then c[k] = v end end
    return c
end

function W.Open(name)
    name = Safe.Str(name)
    if not name then return nil end
    name = strtrim(name)
    if name == "" then return nil end
    name = name:sub(1, 1):upper() .. name:sub(2)
    local c = Ensure(PlayerKey(name), { target = name, realm = RealmPart(name) })
    c.name = c.name or Short(name)
    c.archived = nil
    TrimConvs()
    Notify(c, nil, false)
    return c
end

local function BNTag(id)
    local bn = _G["C_BattleNet"]
    local info = bn and bn.GetAccountInfoByID and Safe.Call(bn.GetAccountInfoByID, id)
    return type(info) == "table" and Safe.Str(info.battleTag) or nil
end

function W.BNGame(conv)
    local bn = _G["C_BattleNet"]
    local id = conv.bn and conv.bnID
    if not bn or not bn.GetAccountInfoByID or not id then return nil end
    local info = Safe.Call(bn.GetAccountInfoByID, id)
    local game = type(info) == "table" and info.gameAccountInfo
    if type(game) ~= "table" or not game.isOnline then return nil end
    local char = Safe.Str(game.characterName)
    if not char or char == "" then return nil end
    local realm = Safe.Str(game.realmName)
    return realm and realm ~= "" and (char .. " (" .. realm .. ")") or char
end

-- presence id of a BattleTag this session (ids change between sessions)
local function BNResolve(tag)
    local bn, num = _G["C_BattleNet"], _G["BNGetNumFriends"]
    if not bn or not bn.GetFriendAccountInfo or not num then return nil end
    for i = 1, Safe.Num(Safe.Call(num)) or 0 do
        local info = Safe.Call(bn.GetFriendAccountInfo, i)
        if type(info) == "table" and Safe.Str(info.battleTag) == tag then
            return Safe.Num(info.bnetAccountID)
        end
    end
    return nil
end

-- conversation with a Battle.net friend by the |K account token
function W.OpenBN(accountName)
    accountName = Safe.Str(accountName)
    local bn, num = _G["C_BattleNet"], _G["BNGetNumFriends"]
    if not accountName or not bn or not bn.GetFriendAccountInfo or not num then return nil end
    for i = 1, Safe.Num(Safe.Call(num)) or 0 do
        local info = Safe.Call(bn.GetFriendAccountInfo, i)
        if type(info) == "table" and Safe.Str(info.accountName) == accountName then
            local tag, id = Safe.Str(info.battleTag), Safe.Num(info.bnetAccountID)
            if not tag or not id then return nil end
            local c = Ensure("bn:" .. tag:lower(), { bn = true, target = tag, bnID = id, kname = accountName })
            c.name = tag:match("^([^#]+)") or tag
            c.archived = nil
            TrimConvs()
            Notify(c, nil, false)
            return c
        end
    end
    return nil
end

function W.Add(out, text, who, guid, bnID)
    text = Safe.Str(text)
    if not text then return nil end
    local c
    if bnID ~= nil then
        local id = Safe.Num(bnID)
        if not id then return nil end
        local tag = BNTag(id)
        local key = tag and ("bn:" .. tag:lower()) or ("bnid:" .. id)
        c = Ensure(key, { bn = true, target = tag, bnID = id, kname = Safe.Str(who) })
        c.name = (tag and tag:match("^([^#]+)")) or c.name or Safe.Str(who) or "Battle.net"
    else
        local full = Safe.Str(who)
        if not full or full == "" then return nil end
        c = Ensure(PlayerKey(full), { target = full, class = ClassOf(guid), realm = RealmPart(full) })
        c.name = Short(full)
    end
    local msg = { t = time(), o = out or nil, m = text }
    c.archived = nil  -- a new message brings it back from the archive
    c.msgs[#c.msgs + 1] = msg
    c.last = msg.t
    Trim(c)
    if not out and not (W.viewing and W.viewing(c.key)) then
        c.unread = (c.unread or 0) + 1
    end
    TrimConvs()
    Notify(c, msg, not out)
    return c
end

-- a hidden message the player chose to see: the notice becomes the text
function W.Uncensor(marker, text)
    for _, c in pairs(Convs()) do
        for _, m in ipairs(c.msgs or {}) do
            if type(m.m) == "string" and m.m:find(marker, 1, true) then
                m.m = text
                Notify(c, m, false)
                return true
            end
        end
    end
    return false
end

function W.MarkRead(conv)
    if conv and (conv.unread or 0) > 0 then
        conv.unread = 0
        Notify(conv, nil, false)
    end
end

function W.Archive(key)
    local c = Convs()[key]
    if not c or c.archived then return end
    c.archived = time()
    c.unread = 0
    Notify(c, nil, false)
end

function W.Restore(key)
    local c = Convs()[key]
    if not c or not c.archived then return end
    c.archived = nil
    Notify(c, nil, false)
end

function W.Delete(key)
    local c = Convs()[key]
    if not c then return end
    Convs()[key] = nil
    Notify(c, nil, false)
end

local function SeqLen(b)
    if b >= 0xF0 then return 4 elseif b >= 0xE0 then return 3 elseif b >= 0xC0 then return 2 end
    return 1
end

local function HardCut(word, max, out)
    local i, n, start = 1, #word, 1
    while i <= n do
        local len = SeqLen(word:byte(i))
        if i + len - start > max then
            out[#out + 1] = word:sub(start, i - 1)
            start = i
        end
        i = i + len
    end
    if start <= n then out[#out + 1] = word:sub(start) end
end

function W.Split(text, max)
    max = max or MAX_BYTES
    if #text <= max then return { text } end
    -- links are atoms: never split inside one
    local links = {}
    local function Protect(l)
        links[#links + 1] = l
        return "\001" .. #links .. "\001"
    end
    local masked = text:gsub("|c[^|]*|H.-|h.-|h|r", Protect):gsub("|H.-|h.-|h", Protect)
    local function Restore(s) return (s:gsub("\001(%d+)\001", function(n) return links[tonumber(n)] end)) end

    local out, line = {}, ""
    for word in masked:gmatch("%S+") do
        local real = Restore(word)
        local candidate = line == "" and real or (line .. " " .. real)
        if #candidate <= max then
            line = candidate
        else
            if line ~= "" then out[#out + 1] = line end
            if #real <= max then
                line = real
            else
                HardCut(real, max, out)
                line = table.remove(out)
            end
        end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
end

-- the server strips spell links with a bracket part: it goes before sending
function W.CleanSpellLinks(text)
    return (text:gsub("(|Hspell:[^|]*|h%[)(.-)%s*%b()(%]|h)", "%1%2%3"))
end

function W.Send(conv, text)
    text = Safe.Str(text) and strtrim(text) or ""
    text = W.CleanSpellLinks(text)
    if not conv or text == "" then return false, "empty" end
    if Safe.InLockdown() then return false, "lockdown" end
    local chunks = W.Split(text, MAX_BYTES)
    if conv.bn then
        local id = (conv.target and BNResolve(conv.target)) or conv.bnID
        local send = _G["BNSendWhisper"]
        if not id or not send then return false, "offline" end
        conv.bnID = id
        for _, c in ipairs(chunks) do send(id, c) end
        return true
    end
    local info = _G["C_ChatInfo"]
    local legacy = "SendChatMessage"  -- older clients only have the global
    local send = (info and info.SendChatMessage) or _G[legacy]
    if not send or not conv.target then return false, "offline" end
    for _, c in ipairs(chunks) do send(c, "WHISPER", nil, conv.target) end
    return true
end

ns.OnReady(function()
    -- Battle.net ids and tokens are only valid in their session
    for _, c in pairs(Convs()) do c.kname, c.bnID = nil, nil end
    W.Purge()
    ns.Listen("CHAT_MSG_WHISPER", function(_, text, sender, ...)
        local guid = select(10, ...)
        W.Add(false, text, sender, guid)
    end)
    ns.Listen("CHAT_MSG_WHISPER_INFORM", function(_, text, target, ...)
        local guid = select(10, ...)
        W.Add(true, text, target, guid)
    end)
    ns.Listen("CHAT_MSG_BN_WHISPER", function(_, text, sender, ...)
        W.Add(false, text, sender, nil, select(11, ...) or false)
    end)
    ns.Listen("CHAT_MSG_BN_WHISPER_INFORM", function(_, text, target, ...)
        W.Add(true, text, target, nil, select(11, ...) or false)
    end)
end)
