--[[
  Style: the browser's tokens and number formats (colours are Sendit.Theme roles).
  Style.size / space / font / surface;  Style.Hex(role) -> r, g, b, "|cffrrggbb"
  Style.Pct(v) / Threshold() / Upgrade(boost) / FitRole(fit)
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

local TRADE_OFF = -0.5  -- a loss below this is worth saying (like Upgrade's tooltip)

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
