--[[
  Rolls: group loot rolls, summed up and shown with flair.

  State comes from CHAT_MSG_LOOT itself (once per event); the chat display
  (Rolls.Style, called per mirrored line, maybe for several windows) only
  reads that state, so a line shown in two windows never counts twice.

  Lines (client templates turned into patterns, like Core/Loot.lua):
    you won          <dice> Won!  <icon>[Item]  You 87 Need - Bob 45 Need     (gold) + card
    you lost         <dice> Lost  <icon>[Item]  Bob 92 Need - You 45 Need     (red) + card
    others won       -> <icon>[Item]  Bob 92 Need - Ann Greed                 (muted)
    everyone passed  Everyone passed: [Item]                                  (muted)
  The names list everyone who took part (first names, winner first and
  white, highest roll first, at most 5 + "+N"); passers are left out.
  While ns.db.rollSummary is on (default) that is the only line per item
  (one line instead of many): roll start, every choice and roll (yours too)
  and the receipt line right after the result are dropped. Off: your choice
  and roll show compact, the rest as the client writes it.

  Rolls.Style(text) -> new text | false (drop the line) | nil (not a roll)
  Rolls.RecentlyWon(link) -> true for a while after you won it (the loot
  card for receiving it is skipped then: the "won" card already showed it)
]]
local _, ns = ...
local Safe, Loot = ns.Safe, ns.Loot
local L = ns.L

local Rolls = {}
ns.Rolls = Rolls

local MUTED = "|cff8a8f9c"
local GOLD = "|cffffd100"
local RED = "|cffff6464"
local KEEP = 300          -- seconds a roll is remembered
local WON_WINDOW = 30     -- seconds the "won" card stands for the loot card

local ICONS = {
    need = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    greed = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    de = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
    pass = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}

-- global, roles in argument order, what, roll kind. Order matters: the more
-- specific template first (the "you" forms before "%s ...", auto-pass
-- before pass, the short "no spam" forms first of all).
local TEMPLATES = {
    { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", { "value", "link" }, "won", "need" },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", { "value", "link" }, "won", "greed" },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", { "value", "link" }, "won", "de" },
    { "LOOT_ROLL_WON_NO_SPAM_NEED", { "who", "value", "link" }, "result", "need" },
    { "LOOT_ROLL_WON_NO_SPAM_GREED", { "who", "value", "link" }, "result", "greed" },
    { "LOOT_ROLL_WON_NO_SPAM_DE", { "who", "value", "link" }, "result", "de" },
    { "LOOT_ROLL_YOU_WON", { "link" }, "won" },
    { "LOOT_ROLL_ROLLED_NEED", { "value", "link", "who" }, "roll", "need" },
    { "LOOT_ROLL_ROLLED_GREED", { "value", "link", "who" }, "roll", "greed" },
    { "LOOT_ROLL_ROLLED_DE", { "value", "link", "who" }, "roll", "de" },
    { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", { "value", "link", "who" }, "roll", "need" },
    { "LOOT_ROLL_LOST_ROLL", { "kindname", "value", "link" }, "myroll" },
    { "LOOT_ROLL_NEED_SELF", { "link" }, "mine", "need" },
    { "LOOT_ROLL_GREED_SELF", { "link" }, "mine", "greed" },
    { "LOOT_ROLL_DISENCHANT_SELF", { "link" }, "mine", "de" },
    { "LOOT_ROLL_PASSED_SELF_AUTO", { "link" }, "mine", "pass" },
    { "LOOT_ROLL_PASSED_SELF", { "link" }, "mine", "pass" },
    { "LOOT_ROLL_ALL_PASSED", { "link" }, "allpassed" },
    { "LOOT_ROLL_WON", { "who", "link" }, "result" },
    { "LOOT_ROLL_NEED", { "who", "link" }, "choice", "need" },
    { "LOOT_ROLL_GREED", { "who", "link" }, "choice", "greed" },
    { "LOOT_ROLL_DISENCHANT", { "who", "link" }, "choice", "de" },
    { "LOOT_ROLL_PASSED_AUTO", { "who", "link" }, "choice", "pass" },
    { "LOOT_ROLL_PASSED_AUTO_FEMALE", { "who", "link" }, "choice", "pass" },
    { "LOOT_ROLL_PASSED", { "who", "link" }, "choice", "pass" },
    -- another player receiving an item: dropped right after its roll result
    { "LOOT_ITEM_MULTIPLE", { "who", "link", "count" }, "theirloot" },
    { "LOOT_ITEM", { "who", "link" }, "theirloot" },
    -- "[Loot]: <item>" alone: a roll starts. Matches any loot-history line,
    -- so it must stay last.
    { "LOOT_ROLL_STARTED", { "link" }, "started" },
}

local compiled
local function Patterns()
    if compiled then return compiled end
    compiled = {}
    for _, t in ipairs(TEMPLATES) do
        local fmt, roles = _G[t[1]], t[2]
        -- Modern templates start with a clickable "[Loot]" history link whose
        -- id is the first argument: "|HlootHistory:%d|h[Loot]|h: ...".
        if type(fmt) == "string" and fmt:find("^|HlootHistory:%%d") then
            roles = { "history", unpack(roles) }
        end
        local pat, order = Loot.Compile(fmt, roles)
        if pat then compiled[#compiled + 1] = { pat = pat, order = order, what = t[3], kind = t[4] } end
    end
    return compiled
end

-- -> { what, kind, who, value, link }, s, e
function Rolls.Parse(text)
    if not Safe.Str(text) then return nil end
    for _, p in ipairs(Patterns()) do
        local res = { text:find(p.pat) }
        if res[1] then
            local info = { what = p.what, kind = p.kind }
            for i, role in ipairs(p.order) do info[role] = res[i + 2] end
            info.value = tonumber(info.value or "")
            local link = info.link
            -- "started" matches any loot-history line: only when the rest is one link
            local ok = link and link:find("|H", 1, true)
                and (p.what ~= "started" or link:match("^|c[^|]*|H[^|]+|h[^|]*|h|r$") or link:match("^|H[^|]+|h[^|]*|h$"))
            if ok then return info, res[1], res[2] end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
-- key -> { mine, myValue, choices = { [who] = kind }, rolls = { [who] = { value, kind } },
--          t, won, decided }
local items = {}

local function Key(link) return link:match("|H(item:[^|]+)|h") or link end

local function Entry(link, create)
    local now = GetTime()
    for k, e in pairs(items) do
        if now - e.t > KEEP then items[k] = nil end
    end
    local k = Key(link)
    if not items[k] and create then items[k] = { rolls = {}, choices = {}, t = now } end
    return items[k]
end
Rolls._Entry = Entry

local function IsMe(who)
    who = Safe.Str(who)
    if not who then return false end
    local me = Safe.Str(Safe.Call(_G["UnitName"], "player"))
    local you = Safe.Str(_G["YOU"])
    if who == me or (you ~= nil and who == you) then return true end
    if not me then return false end
    -- Forever names can carry a surname ("Shac Sendit") and other realms a suffix
    return who:gsub("%-.*$", "") == me or who:sub(1, #me + 1) == me .. " "
end
Rolls._IsMe = IsMe

local function KindName(kind)
    return (kind == "need" and L.NEED) or (kind == "greed" and L.GREED) or (kind == "de" and L.DISENCHANT)
        or L.PASS
end

-- "Gier" / "Bedarf" (client words in LOOT_ROLL_LOST_ROLL) -> roll kind
function Rolls.KindOf(word)
    word = Safe.Str(word)
    if not word then return nil end
    if word == Safe.Str(_G["NEED"]) then return "need" end
    if word == Safe.Str(_G["GREED"]) then return "greed" end
    if word == Safe.Str(_G["ROLL_DISENCHANT"]) then return "de" end
    return nil
end

-- "Shearzad Sturmbringer-Realm" -> "Shearzad": keeps the result line short.
function Rolls.First(name)
    return ((name:match("^(%S+)") or name):gsub("%-.*$", ""))
end

-- Who took part: everyone who chose need/greed/disenchant or rolled, you as
-- "You", the winner marked; highest roll first, players without a roll
-- (greed while someone needed) after them.
local KIND_ORDER = { need = 1, greed = 2, de = 3 }
local function Participants(e, winner, winnerValue, winnerKind)
    local byKey, list = {}, {}
    local function Add(who, kind, value, me)
        local key = me and "\0me" or who
        local p = byKey[key]
        if not p then
            p = { name = me and L.YOU_SHORT or Rolls.First(who), me = me }
            byKey[key] = p
            list[#list + 1] = p
        end
        if value then p.value, p.kind = value, kind or p.kind else p.kind = p.kind or kind end
        return p
    end
    if e then
        for who, kind in pairs(e.choices) do
            if kind ~= "pass" then Add(who, kind, nil, IsMe(who)) end
        end
        for who, r in pairs(e.rolls) do Add(who, r.kind, r.value, IsMe(who)) end
        if e.mine and e.mine ~= "pass" then Add(nil, e.mine, e.myValue, true) end
    end
    if winner == true then
        Add(nil, winnerKind, winnerValue, true).winner = true
    elseif winner then
        Add(winner, winnerKind, winnerValue, IsMe(winner)).winner = true
    end
    table.sort(list, function(a, b)
        if a.winner ~= b.winner then return a.winner == true end
        if (a.value ~= nil) ~= (b.value ~= nil) then return a.value ~= nil end
        if a.value and b.value and a.value ~= b.value then return a.value > b.value end
        local ka, kb = KIND_ORDER[a.kind] or 9, KIND_ORDER[b.kind] or 9
        if ka ~= kb then return ka < kb end
        return a.name < b.name
    end)
    return list
end
Rolls._Participants = Participants

local MAX_NAMES = 5
local function Names(list)
    local parts = {}
    for i, p in ipairs(list) do
        if i > MAX_NAMES then
            parts[#parts + 1] = MUTED .. "+" .. (#list - MAX_NAMES) .. "|r"
            break
        end
        local s = p.name .. (p.value and (" " .. p.value) or "") .. (p.kind and (" " .. KindName(p.kind)) or "")
        parts[#parts + 1] = (p.winner and "|cffffffff" or MUTED) .. s .. "|r"
    end
    return table.concat(parts, MUTED .. " · |r")
end

-- The winner's roll: from the result line itself or the roll lines before it.
local function WinnerRoll(info, e)
    if info.value then return info.value, info.kind end
    local r = e and info.who and e.rolls[info.who]
    if r then return r.value, r.kind end
    return nil
end

function Rolls.OnEvent(_, text)
    local info = Rolls.Parse(text)
    if not info then return end
    local e = Entry(info.link, true)
    e.t = GetTime()
    if info.what == "mine" then
        e.mine = info.kind
    elseif info.what == "choice" then
        e.choices[info.who] = info.kind
    elseif info.what == "myroll" then
        e.myValue = info.value
        e.mine = e.mine or Rolls.KindOf(info.kindname)
    elseif info.what == "roll" then
        e.rolls[info.who] = { value = info.value, kind = info.kind }
        if IsMe(info.who) then e.myValue, e.mine = info.value, e.mine or info.kind end
    elseif info.what == "won" or info.what == "result" or info.what == "allpassed" then
        e.decided = GetTime()
    end
    if info.what == "won" then
        e.won = GetTime()
        local value, kind = info.value or e.myValue, info.kind or e.mine
        if ns.LootCards and ns.db.lootCards then
            ns.LootCards.Show(info.link, nil, {
                state = "won", note = value and (KindName(kind) .. " " .. value) or nil,
            })
        end
    elseif info.what == "result" and not IsMe(info.who) then
        if e.mine and e.mine ~= "pass" and ns.LootCards and ns.db.lootCards then
            local value = WinnerRoll(info, e)
            local note = L.LOST_TO:format(Rolls.First(info.who))
            if value and e.myValue then note = note .. "  ·  " .. value .. " : " .. e.myValue end
            ns.LootCards.Show(info.link, nil, { state = "lost", note = note })
        end
    end
end

function Rolls.RecentlyWon(link)
    local e = Entry(link, false)
    return e ~= nil and e.won ~= nil and GetTime() - e.won < WON_WINDOW
end

-- The item's roll was just decided (its receipt line repeats the result).
function Rolls.RecentlyDecided(link)
    local e = Entry(link, false)
    return e ~= nil and e.decided ~= nil and GetTime() - e.decided < WON_WINDOW
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------
local function Icon(kind)
    local tex = ICONS[kind or "need"] or ICONS.need
    return "|T" .. tex .. ":0|t "
end

local function ItemTag(link)
    local item = Loot.Item(link)
    return (item.icon and ("|T" .. item.icon .. ":0:0:0:0:64:64:5:59:5:59|t ") or "") .. link
end

-- With rollSummary on, one line per item: its result. Start, choices and
-- rolls (yours included: the result names them) and the receipt right after
-- the result are dropped.
local SUMMED = { mine = true, myroll = true, started = true, choice = true }

local function Line(info)
    local e = Entry(info.link, false)
    local what = info.what
    if ns.db.rollSummary then
        if SUMMED[what] or what == "roll" then return false end
        if what == "theirloot" then
            if Rolls.RecentlyDecided(info.link) then return false end
            return nil
        end
    end
    if what == "theirloot" then return nil end
    if what == "mine" then
        return Icon(info.kind) .. MUTED .. KindName(info.kind) .. "|r  " .. info.link
    elseif what == "choice" then
        if ns.db.rollSummary then return false end
        return nil
    elseif what == "roll" then
        if IsMe(info.who) then
            return Icon(info.kind) .. "|cffffffff" .. info.value .. "|r " .. MUTED .. KindName(info.kind)
                .. "|r  " .. info.link
        end
        if ns.db.rollSummary then return false end
        return nil
    elseif what == "won" then
        local value, kind = info.value or (e and e.myValue), info.kind or (e and e.mine)
        local names = Names(Participants(e, true, value, kind))
        return Icon(kind) .. GOLD .. L.WON .. "|r  " .. ItemTag(info.link) .. "  " .. names
    elseif what == "result" then
        local value, kind = WinnerRoll(info, e)
        local names = Names(Participants(e, info.who, value, kind))
        if e and e.mine and e.mine ~= "pass" then
            return Icon(e.mine) .. RED .. L.LOST .. "|r  " .. ItemTag(info.link) .. "  " .. names
        end
        return MUTED .. "→|r " .. ItemTag(info.link) .. "  " .. names
    elseif what == "myroll" then
        local kind = Rolls.KindOf(info.kindname) or (e and e.mine)
        return Icon(kind) .. "|cffffffff" .. info.value .. "|r " .. MUTED .. (info.kindname or "") .. "|r  " .. info.link
    elseif what == "started" then
        return Icon("need") .. MUTED .. L.ROLLING .. "|r  " .. ItemTag(info.link)
    elseif what == "allpassed" then
        return Icon("pass") .. MUTED .. L.ALL_PASSED .. "|r  " .. info.link
    end
    return nil
end

function Rolls.Style(text)
    local info, s, e = Rolls.Parse(text)
    if not info or not Loot.SystemPrefix(text, s) then return nil end
    local line = Line(info)
    if line == false or line == nil then return line end
    return text:sub(1, s - 1) .. line .. text:sub(e + 1)
end

ns.OnReady(function()
    ns.Listen("CHAT_MSG_LOOT", Rolls.OnEvent)
end)
