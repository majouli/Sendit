--[[
  Database: search and chain graphs.
  Search: all words must match - a number = the quest's ID or any linked item / NPC / object ID
  (Data/Search.lua); * and ? are wildcards; else text in names (suite language and English),
  objectives, place and linked names (Data/Search_<locale>.lua).
  Chains: edges from prerequisite to dependent (Kahn order, cycles flagged, missing quests kept);
  exclusive / group siblings are no edges. Only the suite language's texts stay loaded.
  Groups: the filter's places, categories and instances (dungeon / raid: Data/Groups.lua groupKinds);
  an instance also lists the quests whose objectives are inside it (questInstances).
  DB.Faction(id) -> "alliance" | "horde" | nil (both): from the race mask's low word.
]]
local _, ns = ...
local DB = {}
ns.Database = DB
local before, after
local logTitles = {}

-- only the suite language's texts stay in memory (English until /reload after a switch)
Sendit.OnReady(function()
    local keep = Sendit.Locale.Code()
    for _, byCode in ipairs({ ns.names, ns.objectives, ns.searchText }) do
        local fallback = not byCode[keep] and "enUS"
        for code in pairs(byCode) do
            if code ~= keep and code ~= fallback then byCode[code] = nil end
        end
    end
end)

function DB.Name(id)
    local names = ns.names[Sendit.Locale.Code()]
    return names and names[id] or (ns.quests[id] and ns.quests[id].name) or logTitles[id] or ("#" .. id)
end

function DB.Description(id)
    local texts = ns.objectives[Sendit.Locale.Code()]
    local q = ns.quests[id]
    local text = texts and texts[id] or (q and table.concat(q.objectivesText or {}, "\n"))
    if not text or text == "" then return ns.L.noDescription end
    return (text:gsub("%$[Bb]", "\n"))
end

function DB.GroupKey(id)
    local q = ns.quests[id]
    if q and q.areaId then return "area:" .. q.areaId end
    if q and q.sortId then return "sort:" .. q.sortId end
    return "ungrouped"
end

function DB.GroupName(key)
    if key == "all" then return ns.L.allGroups end
    if key == "ungrouped" then return ns.L.noGroup end
    local labels = ns.groups[Sendit.Locale.Code()] or ns.groups.enUS
    return labels[key] or ns.groups.enUS[key] or key
end

function DB.Groups()
    local seen, list = {}, {}
    for id in pairs(ns.quests) do seen[DB.GroupKey(id)] = true end
    for _, key in pairs(ns.questInstances or {}) do seen[key] = true end
    for key in pairs(seen) do
        local instance = ns.groupKinds and ns.groupKinds[key]
        local kind = instance and ns.L[instance] or key:match("^area:") and ns.L.place or ns.L.category
        list[#list + 1] = { key, kind .. ": " .. DB.GroupName(key) }
    end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    table.insert(list, 1, { "all", ns.L.allGroups })
    return list
end

local function Fold(s)
    return (strlower or string.lower)(s)
end

local bundled = ns.quests
local hay, hayCode, hayQuests = {}, nil, nil
local function Haystack(key)
    local code = Sendit.Locale.Code()
    if hayCode ~= code or hayQuests ~= ns.quests then hay, hayCode, hayQuests = {}, code, ns.quests end
    local h = hay[key]
    if h then return h end
    local q = ns.quests[key] or {}
    local texts = ns.objectives[code]
    local linked = ns.quests == bundled and (ns.searchText[code] or ns.searchText.enUS) or {}
    h = Fold(table.concat({ DB.Name(key), q.name or "", texts and texts[key] or "",
        table.concat(q.objectivesText or {}, "\n"), DB.GroupName(DB.GroupKey(key)), linked[key] or "" }, "\n"))
    hay[key] = h
    return h
end

local function Terms(query)
    local terms = {}
    for word in query:gmatch("%S+") do
        local id = tonumber(word)
        if id and id > 0 and id % 1 == 0 then
            terms[#terms + 1] = { id = id, text = tostring(id) }
        elseif word:find("[%*%?]") then
            local pattern = word:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".")
            terms[#terms + 1] = { pattern = pattern }
        else
            terms[#terms + 1] = { plain = word }
        end
    end
    return terms
end

local function Matches(key, terms)
    for _, t in ipairs(terms) do
        local ok
        if t.id then
            ok = key == t.id or (ns.quests == bundled and (ns.searchIds[key] or ""):find(" " .. t.text .. " ", 1, true) ~= nil)
                or Haystack(key):find(t.text, 1, true) ~= nil
        elseif t.pattern then
            ok = Haystack(key):find(t.pattern) ~= nil
        else
            ok = Haystack(key):find(t.plain, 1, true) ~= nil
        end
        if not ok then return false end
    end
    return true
end
DB.Matches = function(key, query) return Matches(key, Terms(Fold(query))) end

local WORD = 4294967296  -- the masks carry flags above bit 31: only the low word counts
local ALLIANCE, HORDE = 1 + 4 + 8 + 64, 2 + 16 + 32 + 128  -- race bits (Human Dwarf NightElf Gnome / Orc Undead Tauren Troll)

local function Any(mask, races)
    for bit = 0, 7 do
        if math.floor(races / 2 ^ bit) % 2 == 1 and math.floor(mask / 2 ^ bit) % 2 == 1 then return true end
    end
    return false
end

function DB.Faction(id)
    local q = ns.quests[id]
    local mask = q and type(q.requiredRaces) == "number" and q.requiredRaces % WORD or 0
    if mask == 0 then return nil end
    local a, h = Any(mask, ALLIANCE), Any(mask, HORDE)
    if a and not h then return "alliance" end
    if h and not a then return "horde" end
    return nil
end

-- faction: "alliance" | "horde" hides the other faction's quests; nil / "all" shows both
function DB.Search(query, group, status, faction)
    query = Fold(strtrim(query or ""))
    local id, out = tonumber(query), {}
    local terms = Terms(query)
    logTitles = ns.Progress.Log()
    for key, quest in pairs(ns.quests) do
        local groupKey = DB.GroupKey(key)
        local inGroup = not group or group == "all" or groupKey == group
            or (ns.questInstances and ns.questInstances[key] == group)
        local state = status and status ~= "all" and ns.Progress.State(key)
        local inState = not state or state == status or
            (status == "unfinished" and (state == "pending" or state == "active"))
        local side = faction and faction ~= "all" and DB.Faction(key)
        local inFaction = not side or side == faction
        if inGroup and inState and inFaction and (query == "" or Matches(key, terms)) then
            out[#out + 1] = key
        end
    end
    for key, title in pairs(logTitles) do
        if not ns.quests[key] and (not group or group == "all" or group == "ungrouped")
            and (not status or status == "all" or status == "active" or status == "unfinished")
            and (query == "" or key == id or Fold(title):find(query, 1, true)) then out[#out + 1] = key end
    end
    table.sort(out, function(a, b)
        if a == b then return false end
        local activeA, activeB = logTitles[a] ~= nil or ns.Progress.State(a) == "active", logTitles[b] ~= nil or ns.Progress.State(b) == "active"
        if activeA ~= activeB then return activeA end
        if a == id then return true end
        if b == id then return false end
        local an, bn = Fold(DB.Name(a)), Fold(DB.Name(b))
        if (an == query) ~= (bn == query) then return an == query end
        return an == bn and a < b or an < bn
    end)
    return out
end

local function Index()
    before, after = {}, {}
    local function Edge(a, b)
        if type(a) ~= "number" or type(b) ~= "number" or a <= 0 or b <= 0 then return end
        after[a], before[b] = after[a] or {}, before[b] or {}
        after[a][b], before[b][a] = true, true
    end
    for id, q in pairs(ns.quests) do
        for _, prev in ipairs(q.preQuestGroup or {}) do Edge(prev, id) end
        for _, prev in ipairs(q.preQuestSingle or {}) do Edge(prev, id) end
        Edge(id, q.nextQuestInChain)
        Edge(q.parentQuest, id)
        for _, child in ipairs(q.childQuests or {}) do Edge(id, child) end
    end
end

function DB.Links(id, direction)
    if not before then Index() end
    local out = {}
    local links
    if direction == "before" then links = before[id] else links = after[id] end
    for key in pairs(links or {}) do out[#out + 1] = key end
    table.sort(out)
    return out
end

-- known prerequisites { all, any }: the explicit lists, else every recorded link before it
-- (a previous quest's "next", a parent quest)
function DB.Prerequisites(id)
    local q = ns.quests[id]
    if q and (q.preQuestGroup or q.preQuestSingle) then
        local all, any = {}, {}
        for _, p in ipairs(q.preQuestGroup or {}) do all[#all + 1] = p end
        for _, p in ipairs(q.preQuestSingle or {}) do any[#any + 1] = p end
        if #any == 1 then all[#all + 1], any = any[1], {} end
        return { all = all, any = any }
    end
    return { all = DB.Links(id, "before"), any = {} }
end

function DB.Chain(id)
    if not before then Index() end
    local members, queue = { [id] = true }, { id }
    local pos = 1
    while pos <= #queue do
        local current = queue[pos]
        pos = pos + 1
        for _, links in ipairs({ before[current] or {}, after[current] or {} }) do
            for key in pairs(links) do
                if not members[key] then members[key], queue[#queue + 1] = true, key end
            end
        end
    end
    local degree, depth, ready, rows = {}, {}, {}, {}
    for key in pairs(members) do
        degree[key], depth[key] = 0, 0
        for prev in pairs(before[key] or {}) do if members[prev] then degree[key] = degree[key] + 1 end end
        if degree[key] == 0 then ready[#ready + 1] = key end
    end
    while #ready > 0 do
        table.sort(ready)
        local key = table.remove(ready, 1)
        rows[#rows + 1] = { id = key, depth = depth[key] }
        for nextID in pairs(after[key] or {}) do
            depth[nextID] = math.max(depth[nextID], depth[key] + 1)
            degree[nextID] = degree[nextID] - 1
            if degree[nextID] == 0 then ready[#ready + 1] = nextID end
        end
        members[key] = nil
    end
    local cycle = next(members) ~= nil
    local remaining = {}
    for key in pairs(members) do remaining[#remaining + 1] = key end
    table.sort(remaining)
    for _, key in ipairs(remaining) do rows[#rows + 1] = { id = key, depth = 0, cycle = true } end
    return rows, cycle
end

function DB.Invalidate() before, after = nil, nil end
