--[[
  Style: the browser's design tokens and number formats - sizes, spacing,
  text roles, surfaces, and the boost texts. Components never hard-code these.
  Colours are Sendit.Theme roles (follow the palette live): gold accent for
  selection and upgrades, success green for "your level", muted for the rest.

  Style.size / space / font / surface      tokens
  Style.Hex(role) -> r, g, b, "|cffrrggbb"
  Style.Pct(v) -> "1,2" (the language's decimal mark)
  Style.Threshold() -> "1" / "0,5"
  Style.Upgrade(boost) -> "+1,2 % Damage" (+ "(from level 45)" for a preview item,
                          + a real loss in the second metric, red)
  Style.FitRole(fit) -> colour role of Database.Fit
]]
local _, ns = ...
local Style = {}
ns.Style = Style

Style.size = {
    header = 52, toolbar = 36, paneHead = 30, detailHead = 58,
    row = 58, rowGap = 4, icon = 34, iconGap = 8, chance = 14,
    search = 220, minLeft = 260, wide = 1180,
}
Style.space = { pad = 16, gap = 12, inner = 12, card = 10 }
Style.font = { window = "title", name = "body", meta = "small", caption = "caption", section = "label", heading = "heading" }
Style.surface = { window = "bg", list = "sidebar", row = "panel", rowSelected = "selected", card = "panelAlt", hairline = "border" }

function Style.Hex(role)
    local r, g, b = Sendit.Theme.Color(role)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return r, g, b, ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

function Style.Pct(v)
    return (("%.1f"):format(v):gsub("%.", ns.L.decimal))
end

function Style.Threshold(v)
    v = v or ns.Boost.Min()
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return Style.Pct(v)
end

local TRADE_OFF = -0.5  -- like Upgrade's tooltip: a loss below this is worth saying

function Style.Upgrade(boost)
    local text = "+" .. Style.Pct(boost.pct) .. " % " .. (boost.label or "")
    if boost.gate then
        local _, _, _, dim = Style.Hex("textDim")
        text = text .. "  " .. dim .. "(" .. ns.L.fromLevel:format(boost.gate) .. ")|r"
    end
    if boost.secondaryPct and boost.secondaryPct <= TRADE_OFF then
        local _, _, _, red = Style.Hex("danger")
        text = text .. "  ·  " .. red .. (boost.secondaryLabel or "") .. " " .. Style.Pct(boost.secondaryPct) .. " %|r"
    end
    return text
end

local FIT = { fits = "success", above = "textMuted", below = "textDim", unknown = "textMuted" }
function Style.FitRole(fit) return FIT[fit] or "textDim" end
