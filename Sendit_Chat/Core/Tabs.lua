--[[
  Tabs: the tab list - Blizzard's mirrored chat windows plus Sendit Chat's
  own tabs (a name and the channels / message kinds it takes).

  Why own tabs: a new Blizzard chat window needs FCF_OpenNewWindow, which
  run from addon code writes the chat frames' fields tainted (taint:
  never write Blizzard's chat frames). Own tabs only sort lines Blizzard already added to its main
  window (ChatFrame1): by the line's chat type id (Blizzard's info.id, a
  plain number; channels have one id per channel number), never by the text
  (secret in chat lockdown). A line an own tab takes leaves General; two own
  tabs may take the same line.

  Saved in ns.acct.tabs = { { id, name, take = { [key] = label } } }; key =
  a group ("say", "guild", "group", "loot", "system") or "channel:<name>"
  (channel name without the zone part, lower case - the number changes).
  An own tab's index is OWN_BASE + id, above Blizzard's window indices.

  Tabs.All()                 Blizzard indices (Mirror.Indices) + own indices
  Tabs.Name(index)           tab label
  Tabs.Get(index)            own tab definition or nil
  Tabs.Route(index, infoID)  own tab indices that take the line, or nil (= index)
  Tabs.Choices()             { { key, label }, ... } groups, then joined channels
                             (GetChannelName per number, as the routing reads them)
  Tabs.Save(index|nil, name, take) -> index   create / change an own tab
  Tabs.Delete(index)
]]
local _, ns = ...
local Safe, Mirror, L = ns.Safe, ns.Mirror, ns.L

local Tabs = {}
ns.Tabs = Tabs

local OWN_BASE = 100

local GROUPS = {
    { key = "say",    label = "TAB_SAY",    types = { "SAY", "YELL", "EMOTE", "TEXT_EMOTE" } },
    { key = "guild",  label = "TAB_GUILD",  types = { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT" } },
    { key = "group",  label = "TAB_GROUP",  types = { "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
                                                      "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" } },
    { key = "loot",   label = "TAB_LOOT",   types = { "LOOT", "MONEY", "CURRENCY" } },
    { key = "system", label = "TAB_SYSTEM", types = { "SYSTEM", "SKILL", "COMBAT_FACTION_CHANGE",
                                                      "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "ACHIEVEMENT" } },
}
local groupOf = {}
for _, g in ipairs(GROUPS) do for _, t in ipairs(g.types) do groupOf[t] = g.key end end

local function List()
    ns.acct.tabs = ns.acct.tabs or {}
    return ns.acct.tabs
end

function Tabs.Get(index)
    if type(index) ~= "number" or index <= OWN_BASE then return nil end
    for _, t in ipairs(List()) do
        if OWN_BASE + t.id == index then return t end
    end
    return nil
end

function Tabs.All()
    local all = Mirror.Indices()
    for _, t in ipairs(List()) do all[#all + 1] = OWN_BASE + t.id end
    return all
end

function Tabs.Name(index)
    local t = Tabs.Get(index)
    if t then return t.name end
    return Mirror.Name(index)
end

---------------------------------------------------------------------------
-- Routing
---------------------------------------------------------------------------
-- "Trade - City" -> "channel:trade", "Trade" (the zone part changes).
local function ChannelKey(name)
    name = Safe.Str(name)
    if not name or name == "" then return nil end
    local base = name:match("^(.-)%s+%-%s") or name
    return "channel:" .. base:lower(), base
end

-- Channel number -> key, label; the same source for routing and the editor.
local function Channel(n)
    local fn = _G["GetChannelName"]
    if not fn then return nil end
    local ok, _, name = pcall(fn, n)
    if not ok then return nil end
    return ChannelKey(name)
end

local function KeyOf(infoID)
    local chatType = Mirror.ChatType(infoID)
    if not chatType then return nil end
    local n = chatType:match("^CHANNEL(%d+)$")
    if n then return (Channel(tonumber(n))) end
    return groupOf[chatType]
end

function Tabs.Route(index, infoID)
    if index ~= 1 or #List() == 0 then return nil end
    local key = KeyOf(infoID)
    if not key then return nil end
    local out
    for _, t in ipairs(List()) do
        if t.take and t.take[key] then
            out = out or {}
            out[#out + 1] = OWN_BASE + t.id
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Editing
---------------------------------------------------------------------------
function Tabs.Choices()
    local out = {}
    for _, g in ipairs(GROUPS) do out[#out + 1] = { g.key, L[g.label] } end
    local seen = {}
    for n = 1, _G["MAX_WOW_CHAT_CHANNELS"] or 20 do
        local key, label = Channel(n)
        if key and not seen[key] then
            seen[key] = true
            out[#out + 1] = { key, label, channel = true }
        end
    end
    return out
end

function Tabs.Save(index, name, take)
    local t = Tabs.Get(index)
    if not t then
        local id = 1
        for _, o in ipairs(List()) do if o.id >= id then id = o.id + 1 end end
        t = { id = id }
        List()[#List() + 1] = t
    end
    t.name = name
    t.take = take
    return OWN_BASE + t.id
end

function Tabs.Delete(index)
    local list = List()
    for k, t in ipairs(list) do
        if OWN_BASE + t.id == index then
            table.remove(list, k)
            wipe(ns.History.Lines(index))
            return
        end
    end
end
