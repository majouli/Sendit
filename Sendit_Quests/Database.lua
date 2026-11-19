--[[
  Database: search and deterministic directed chain graphs.
  Search: words, all must match. A number matches the quest's ID or any item,
  NPC or object ID the quest names (Data/Search.lua); * and ? are wildcards;
  else plain text in the quest's name (suite language and English), its
  texts, its place / category and the names of the items, NPCs and objects
  it names (Data/Search_<locale>.lua).
  Edges point from prerequisite to dependent. OR and AND prerequisites stay
  separate in the source record; siblings in an exclusive/group list are
  not invented chain edges. Connected components include all branches.
  Kahn ordering handles converging branches; cycles are surfaced, never
  recursed forever or hidden. Missing referenced quests remain visible.
  Only the suite language's names / objectives stay loaded (see OnReady below).
]]
local _, ns = ...
local DB = {}
ns.Database = DB
local before, after
local logTitles = {}

-- Names and objectives ship in four languages (~2.7 MB, Data/Names_*.lua); once the
-- suite language is known only that one stays in memory. After a language switch
-- the dropped ones show English until /reload.
Sendit.OnReady(function()
    local keep = Sendit.Locale.Code()
    for _, byCode in ipairs({ ns.names, ns.objectives, ns.searchText }) do
        local fallback = not byCode[keep] and "enUS"  -- the linked names exist in English too
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
    for key in pairs(seen) do
        local kind = key:match("^area:") and ns.L.place or ns.L.category
        list[#list + 1] = { key, kind .. ": " .. DB.GroupName(key) }
    end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    table.insert(list, 1, { "all", ns.L.allGroups })
    return list
end

local function Fold(s)
    -- WoW's strlower handles UTF-8; Lua's lower is the test/client fallback.
    return (strlower or string.lower)(s)
end

-- The linked-name index (Data/Search*.lua) belongs to the bundled quest table.
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

function DB.Search(query, group, status)
    query = Fold(strtrim(query or ""))
    local id, out = tonumber(query), {}
    local terms = Terms(query)
    logTitles = ns.Progress.Log()
    for key, quest in pairs(ns.quests) do
        local groupKey = DB.GroupKey(key)
        local inGroup = not group or group == "all" or groupKey == group
        local state = status and status ~= "all" and ns.Progress.State(key)
        local inState = not state or state == status or
            (status == "unfinished" and (state == "pending" or state == "active"))
        if inGroup and inState and (query == "" or Matches(key, terms)) then
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

-- Known prerequisites: { all = {...}, any = {...} }. The source's explicit
-- AND / OR lists when it has them, else every recorded link before it (a
-- previous quest's "next", a parent quest) counts as required.
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

-- Tests replace the fixture database; production data never changes.
function DB.Invalidate() before, after = nil, nil end
