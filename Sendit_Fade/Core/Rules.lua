--[[
  Rules: Rules:Reason(e) -> text, rule (nil when it fades) - "builtin" (tooltips, nameplates, dialogs,
  registered windows and menus), "element", "addon", "pattern" (profile.exclude).
]]
local _, ns = ...

local Rules = {}
ns.Rules = Rules

local NEVER_KINDS = { tooltip = true, nameplate = true }
-- TOOLTIP strata is allowed: addons park HUD parts there
local NEVER_STRATA = { DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true }

local windowNames = {}

-- registered closable windows / menus (Escape closes them)
function Rules:Refresh()
    wipe(windowNames)
    for _, n in ipairs(UISpecialFrames or {}) do windowNames[n] = true end
    for n in pairs(UIPanelWindows or {}) do windowNames[n] = true end
    for _, n in ipairs(UIMenus or {}) do windowNames[n] = true end
end

function Rules:Reason(e)
    if NEVER_KINDS[e.kind] then return ns.L.R_ALWAYS_KIND:format(ns.Names.KindLabel(e.kind)), "builtin" end
    if NEVER_STRATA[e.strata] then return ns.L.R_ALWAYS_DIALOG, "builtin" end
    if not e.anonymous and windowNames[e.name] then return ns.L.R_ALWAYS_WINDOW, "builtin" end
    local ex = ns.profile.exclude
    if ex.elements[e.key] then return ns.L.R_EXCLUDED, "element" end
    if ex.addons[e.owner] then return ns.L.R_ADDON, "addon" end
    local hay = (e.label .. " " .. e.name .. " " .. e.owner .. " " .. e.kind):lower()
    for text in pairs(ex.patterns) do
        if hay:find(text, 1, true) then return ns.L.R_PATTERN:format(text), "pattern" end
    end
end
