--[[
  Style: the journal's design tokens and number formats - one place for
  sizes, spacing, text roles, surface/status colours and the display state
  of a quest. Components never hard-code these.

  Colours are Sendit.Theme roles (follow the palette live): gold accent for
  selection and key accents, success green for done, muted grey for locked.

  Contract:
    Style.size / Style.space / Style.font / Style.surface    tokens
    Style.Number(n)          "8.325" (de) / "8,325" (en): thousands mark per language
    Style.Money(copper)      gold / silver / copper with coin icons, zero parts hidden;
                             nil when unknown (never "0")
    Style.XP(n)              "8.325 EP" or nil when unknown or zero
    Style.Show(id, prev)     display state: done | active | next | locked | open | unknown
                             (locked / next only from known prerequisites in the chain;
                             race, class and reputation gates are not in the data)
    Style.Role(state)        colour role of a display state
]]
local _, ns = ...
local Style = {}
ns.Style = Style

Style.size = {
    header = 52, toolbar = 36, paneHead = 30, chainHead = 66,
    row = 96, rowGap = 4,                -- list rows: title, place line, reward bar, chain line
    icon = 24, iconBig = 34, node = 16, lane = 18,
    step = 46,                           -- a collapsed timeline step
    search = 240, minLeft = 230,
}
Style.space = { pad = 16, gap = 12, inner = 10, line = 4, section = 14 }
Style.font = {
    window = "title", quest = "body", meta = "small", caption = "caption", section = "label", text = "body",
}
Style.surface = {
    window = "bg", list = "sidebar", row = "panel", rowSelected = "selected", step = "panelAlt",
    hairline = "border",
}

local ROLES = {
    done = "success", active = "warning", next = "accent", locked = "textMuted", open = "textDim", unknown = "textMuted",
}
function Style.Role(state) return ROLES[state] or "textDim" end

-- r, g, b, "|cffrrggbb" of a Theme role (for coloured words inside a text).
function Style.Hex(role)
    local r, g, b = Sendit.Theme.Color(role)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return r, g, b, ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

local LABELS = { done = "done", active = "active", next = "stepNext", locked = "locked", open = "pending", unknown = "unknown" }
-- The state's word in its colour.
function Style.Label(state)
    local _, _, _, hex = Style.Hex(Style.Role(state))
    return hex .. ns.L[LABELS[state] or "unknown"] .. "|r"
end

function Style.Number(n)
    local s = tostring(math.floor(n + 0.5))
    local sep = ns.L.thousands
    local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
    if out:sub(1, #sep) == sep then out = out:sub(#sep + 1) end
    return out
end

local COINS = {
    { 10000, "Interface\\MoneyFrame\\UI-GoldIcon" },
    { 100, "Interface\\MoneyFrame\\UI-SilverIcon" },
    { 1, "Interface\\MoneyFrame\\UI-CopperIcon" },
}
function Style.Money(copper)
    if type(copper) ~= "number" or copper <= 0 then return nil end
    local parts = {}
    for i, coin in ipairs(COINS) do
        local n = math.floor(copper / coin[1])
        if i > 1 then n = n % 100 end  -- gold has no upper digit limit (x % huge is NaN in Lua)
        if n > 0 then parts[#parts + 1] = n .. "|T" .. coin[2] .. ":12:12:1:0|t" end
    end
    return table.concat(parts, " ")
end

local function Pct(v) return (("%.1f"):format(v):gsub("%.", ns.L.decimal)) end

-- The boost threshold as text: "1" / "0,5" (the language's decimal mark).
function Style.Threshold()
    local v = ns.Boost.Min()
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return (("%.1f"):format(v):gsub("%.", ns.L.decimal))
end

local TRADE_OFF = -0.5  -- like Upgrade's tooltip: a loss below this is worth saying

-- "+1,0 % Damage": a gear boost result (Boost.Get) - the one number the boost
-- filters and sorts by, the gain for the whole character (as Upgrade's item
-- tooltip). A real loss in the spec's second metric follows in red:
-- "+1,0 % Damage  ·  Survival -2,6 %".
function Style.Upgrade(boost)
    local text = "+" .. Pct(boost.pct) .. " % " .. (boost.label or "")
    if boost.secondaryPct and boost.secondaryPct <= TRADE_OFF then
        local _, _, _, red = Style.Hex("danger")
        text = text .. "  ·  " .. red .. (boost.secondaryLabel or "") .. " " .. Pct(boost.secondaryPct) .. " %|r"
    end
    return text
end

-- The badge tooltip: what the number means, and the slot comparison as info.
function Style.UpgradeDetail(boost)
    return ns.L.detailVs:format(boost.label or "?")
end

function Style.XP(n)
    if type(n) ~= "number" or n <= 0 then return nil end
    return Style.Number(n) .. " " .. ns.L.xp
end

-- What the journal shows for a quest: progress first, then what the chain's
-- known prerequisites say. prev = { all = {...}, any = {...} } quest IDs.
function Style.Show(id, prev)
    local state = ns.Progress.State(id)
    if state ~= "pending" then return state end
    local all, any = prev and prev.all or {}, prev and prev.any or {}
    if #all == 0 and #any == 0 then return "next" end
    for _, p in ipairs(all) do
        local s = ns.Progress.State(p)
        if s == "unknown" then return "open" end
        if s ~= "done" then return "locked" end
    end
    if #any > 0 then
        local unknown = false
        for _, p in ipairs(any) do
            local s = ns.Progress.State(p)
            if s == "done" then return "next" end
            if s == "unknown" then unknown = true end
        end
        return unknown and "open" or "locked"
    end
    return "next"
end
