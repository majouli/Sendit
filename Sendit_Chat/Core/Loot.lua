--[[
  Loot: recognises the player's own loot lines (the client's templates as patterns, every language)
  and restyles them: "+2 <icon> [Item]  Head - Plate", "+ <coins>". Only the matched span changes.
  Loot.Parse(text) -> info, s, e;  Loot.Item(link) -> { quality, icon, r, g, b, detail }
  Loot.Style(text, event) -> text | false (drop, Rolls)
]]
local _, ns = ...
local Safe = ns.Safe

local Loot = {}
ns.Loot = Loot

local EVENTS = { CHAT_MSG_LOOT = true, CHAT_MSG_MONEY = true, CHAT_MSG_CURRENCY = true }
local MUTED = "|cff8a8f9c"
local GAIN = "|cff5fd35f"

-- older clients only have the globals
local function Legacy(name) return _G[name] end

-- template global and the roles of its %s / %d; multiple-count variants first
local TEMPLATES = {
    { "LOOT_ITEM_SELF_MULTIPLE", { "link", "count" } },
    { "LOOT_ITEM_SELF", { "link" } },
    { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", { "link", "count" } },
    { "LOOT_ITEM_PUSHED_SELF", { "link" } },
    { "LOOT_ITEM_CREATED_SELF_MULTIPLE", { "link", "count" } },
    { "LOOT_ITEM_CREATED_SELF", { "link" } },
    { "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE", { "link", "count" } },
    { "LOOT_ITEM_BONUS_ROLL_SELF", { "link" } },
    { "CURRENCY_GAINED_MULTIPLE", { "link", "count" } },
    { "CURRENCY_GAINED", { "link" } },
    { "YOU_LOOT_MONEY", { "money" } },
    { "LOOT_MONEY_SPLIT", { "money" } },
}

local function Escape(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- "%s bekommt Beute: %sx%d." -> pattern + capture roles (positional %2$s honoured)
function Loot.Compile(fmt, roles)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local parts, order, pos, arg = {}, {}, 1, 0
    while true do
        local s, e, num, kind = fmt:find("%%(%d?)%$?([sd])", pos)
        if not s then break end
        parts[#parts + 1] = Escape(fmt:sub(pos, s - 1))
        arg = arg + 1
        local role = roles[tonumber(num) or arg]
        order[#order + 1] = role
        parts[#parts + 1] = kind == "d" and "(%d+)" or "(.-)"
        pos = e + 1
    end
    parts[#parts + 1] = Escape(fmt:sub(pos)) .. "$"
    return table.concat(parts), order
end

local compiled
local function Patterns()
    if compiled then return compiled end
    compiled = {}
    for _, t in ipairs(TEMPLATES) do
        local pat, order = Loot.Compile(_G[t[1]], t[2])
        if pat then compiled[#compiled + 1] = { pat = pat, order = order } end
    end
    return compiled
end

-- "1 Gold, 20 Silber, 5 Kupfer" -> copper (nil when nothing matched)
local function Copper(money)
    local total, found = 0, false
    for _, u in ipairs({ { "GOLD_AMOUNT", 10000 }, { "SILVER_AMOUNT", 100 }, { "COPPER_AMOUNT", 1 } }) do
        local pat = Loot.Compile(_G[u[1]], { "n" })
        if pat then
            local n = money:match(pat:sub(1, -2))  -- no end anchor inside a list
            if n then total, found = total + tonumber(n) * u[2], true end
        end
    end
    return found and total or nil
end
Loot._Copper = Copper

function Loot.Parse(text)
    if not Safe.Str(text) then return nil end
    for _, p in ipairs(Patterns()) do
        local res = { text:find(p.pat) }
        if res[1] then
            local info = {}
            for i, role in ipairs(p.order) do info[role] = res[i + 2] end
            if info.count then info.count = tonumber(info.count) end
            if info.money then
                info.copper = Copper(info.money)
                if not info.copper then return nil end
            end
            if info.link or info.copper then return info, res[1], res[2] end
        end
    end
    return nil
end

local QUALITY_RGB = {
    [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 },
    { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 }, { 0, 0.8, 1 },
}

local function QualityRGB(q)
    local colors = _G["ITEM_QUALITY_COLORS"]
    local c = colors and colors[q]
    if c and c.r then return c.r, c.g, c.b end
    c = QUALITY_RGB[q] or QUALITY_RGB[1]
    return c[1], c[2], c[3]
end
Loot.QualityRGB = QualityRGB

local function Instant(link)
    local item = _G["C_Item"]
    local fn = (item and item.GetItemInfoInstant) or Legacy("GetItemInfoInstant")
    if not fn then return nil end
    local ok, id, _, subType, equipLoc, icon, classID, subclassID = pcall(fn, link)
    if not ok then return nil end
    -- slot and sub category in the suite language; the client's own text when the table lacks it
    if type(classID) == "number" and type(subclassID) == "number" then
        subType = Sendit.Locale.SubClass(classID, subclassID) or subType
    end
    return id, subType, equipLoc, icon, classID
end

local function Quality(link)
    local q = tonumber(link:match("|cnIQ(%d+):") or "")
    if q then return q end
    local item = _G["C_Item"]
    local fn = (item and item.GetItemInfo) or Legacy("GetItemInfo")
    if fn then
        local ok, _, _, quality = pcall(fn, link)
        if ok and Safe.Num(quality) then return quality end
    end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    if hex then
        hex = hex:lower()
        for i = 0, 7 do
            local r, g, b = QualityRGB(i)
            if ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
                math.floor(b * 255 + 0.5)) == hex then return i end
        end
    end
    return 1
end

function Loot.Item(link)
    local q = Quality(link)
    local r, g, b = QualityRGB(q)
    local info = { quality = q, r = r, g = g, b = b }
    if not link:find("|Hitem:", 1, true) then return info end
    local _, subType, equipLoc, icon, classID = Instant(link)
    info.icon = icon
    local slot = type(equipLoc) == "string" and equipLoc ~= "" and Sendit.Locale.Global(equipLoc)
    if classID == 2 then
        info.detail = Safe.Str(subType)
    elseif classID == 4 and type(slot) == "string" then
        local sub = Safe.Str(subType)
        info.detail = (sub and sub ~= "" and sub ~= slot) and (slot .. " · " .. sub) or slot
    else
        -- everything else: the client's sub category ("Stoff", "Fleisch", "Kräuter")
        local sub = Safe.Str(subType)
        if sub and sub ~= "" then info.detail = sub end
    end
    return info
end

local function IconTag(icon)
    if not icon then return "" end
    return "|T" .. icon .. ":0:0:0:0:64:64:5:59:5:59|t "
end

function Loot.Line(info)
    if info.copper then
        local coins = Legacy("GetCoinTextureString")
        local money = coins and Safe.Call(coins, info.copper) or info.money
        return "|cffe6ba66+|r " .. money
    end
    local item = Loot.Item(info.link)
    -- "+N" always; no colour stripe (a tinted stripe renders as a white block here)
    local gain = GAIN .. "+" .. (info.count or 1) .. "|r "
    local detail = item.detail and ("  " .. MUTED .. item.detail .. "|r") or ""
    return gain .. IconTag(item.icon) .. info.link .. detail
end

-- only system text may stand before a match (a player's line has a link in front)
function Loot.SystemPrefix(text, s)
    local prefix = text:sub(1, s - 1)
    return not (prefix:find("|Hplayer", 1, true) or prefix:find("|HBNplayer", 1, true)
        or prefix:find("|Hchannel", 1, true))
end

-- event when known (the client does not always tell): else the templates decide
function Loot.Style(text, event)
    local ev = Safe.Str(event)
    if ev and not EVENTS[ev] then return text end
    local roll = ns.Rolls and ns.Rolls.Style(text)  -- the roll summary has its own switch
    if roll ~= nil then return roll end  -- false = drop the line
    if not ns.db.lootStyle then return text end
    local info, s, e = Loot.Parse(text)
    if not info or not Loot.SystemPrefix(text, s) then return text end
    -- an item you just won: the "won" line already said it
    if info.link and ns.db.rollSummary and ns.Rolls and ns.Rolls.RecentlyWon(info.link) then return false end
    return text:sub(1, s - 1) .. Loot.Line(info) .. text:sub(e + 1)
end
