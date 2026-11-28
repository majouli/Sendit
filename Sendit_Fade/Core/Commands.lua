--[[
  Commands: /fa (/fade) - no arguments opens Fade's pages; profiles are the suite's. Each ns.commands
  entry takes the rest of the line.
]]
local _, ns = ...

local commands = ns.commands
local Safe = ns.Safe

local L = ns.L

local function OnOff(v) return v and ("|cff6bd99a" .. L.CMD_ON .. "|r") or ("|cfff57373" .. L.CMD_OFF .. "|r") end

local function Changed()
    ns.Fader:Sync()
    ns.SettingsChanged()
end

local function Say(text) ns.Print(L.CMD_PROFILE:format(text, ns.Profiles:Active())) end
local function Usage(text) ns.Print(L.CMD_USAGE:format(text)) end

local function FadedCount()
    return (ns.Fader:Count())
end

function commands.toggle()
    ns.profile.enabled = not ns.profile.enabled
    if ns.profile.enabled then ns.Fader:Reset() end
    Changed()
    ns.Print(L.CMD_FADING:format(OnOff(ns.profile.enabled)))
end

-- always restarts the fader (recovers from a paused error)
function commands.on()
    ns.profile.enabled = true
    ns.Fader:Reset()
    Changed()
    ns.Print(L.CMD_FADING:format(OnOff(true)))
end

function commands.off()
    if ns.profile.enabled then commands.toggle() end
end

function commands.alpha(v)
    v = tonumber(v)
    if not v or v < 0 or v > 1 then return Usage("/fa alpha <0-1>") end
    ns.profile.alpha = v
    Changed()
    Say(L.CMD_ALPHA:format(v))
end

function commands.delay(v)
    v = tonumber(v)
    if not v or v < 0 then return Usage("/fa delay <" .. L.CMD_SECONDS .. ">") end
    ns.profile.delay = v
    Changed()
    Say(L.CMD_DELAY:format(v))
end

function commands.speed(rest)
    local out, inn = rest:match("^(%S+)%s*(%S*)$")
    out, inn = tonumber(out), tonumber(inn)
    if not out then return Usage("/fa speed <out> [in]") end
    local p = ns.profile
    p.fadeOut = out
    if inn then p.fadeIn = inn end
    Changed()
    Say(L.CMD_SPEED:format(p.fadeOut, p.fadeIn))
end

function commands.trigger(name)
    local t = ns.profile.triggers
    name = name:lower()
    if t[name] == nil then
        local parts = {}
        for k, v in pairs(t) do parts[#parts + 1] = k .. " " .. OnOff(v) end
        table.sort(parts)
        return Say(L.CMD_TRIGGERS:format(table.concat(parts, ", ")))
    end
    t[name] = not t[name]
    Changed()
    Say(L.CMD_TRIGGER:format(name, OnOff(t[name])))
end

function commands.exclude(text)
    local patterns = ns.profile.exclude.patterns
    text = text:lower()
    if text == "" then
        local t = {}
        for k in pairs(patterns) do t[#t + 1] = k end
        table.sort(t)
        return Say(L.CMD_EXCLUDED:format(#t > 0 and table.concat(t, ", ") or L.CMD_NONE))
    end
    patterns[text] = true
    Changed()
    Say(L.CMD_EXCLUDE:format(text, FadedCount()))
end

function commands.include(text)
    local patterns = ns.profile.exclude.patterns
    text = text:lower()
    if not patterns[text] then return Say(L.CMD_NOT_EXCLUDED:format(text)) end
    patterns[text] = nil
    Changed()
    Say(L.CMD_INCLUDE:format(text, FadedCount()))
end

function commands.status()
    local p = ns.profile
    local n, skipped, contested = ns.Fader:Count()
    ns.Print(("Active %s: fading %s, %d elements (%d enforced, %d skipped), alpha %.2f, delay %gs, out %.2fs / in %.2fs"):format(
        ns.Profiles:Active(), OnOff(p.enabled), n, contested, skipped, p.alpha, p.delay, p.fadeOut, p.fadeIn))
    commands.trigger("")
    commands.exclude("")
end

function commands.scan()
    ns.Scanner:PrintSummary(ns:Rescan())
end

function commands.list(filter)
    ns.Scanner:PrintList(filter)
end

function commands.show()
    ns.Overlay:Toggle()
end

local function InspectLine(e)
    local head = ("%s |cffaaaaaa[%s] (%s, %s, %s)|r"):format(e.label, e.key, e.owner, e.kind, e.strata)
    local s = ns.Fader:State(e.frame)
    if not s then
        local why = ns.Rules:Reason(e) or (ns.profile.enabled and "not managed" or "fading is off")
        return head .. " - |cffffaa00not faded:|r " .. why
    end
    if s.skip then return head .. " - |cffff5555skipped:|r " .. s.skip end
    local mode = s.hooked and "hooked" or s.contested and "enforced every frame"
        or s.canHook and "hookable" or "not hookable"
    return head .. (" - %.2f -> %.2f, base %s, %s, alpha now %s"):format(
        s.cur, s.target or 1, s.base and ("%.2f"):format(s.base) or "-", mode,
        tostring(Safe.Alpha(s.frame) or "secret"))
end

function commands.inspect()
    local r = ns.Scanner.last
    if not r then return ns.Print("No scan yet.") end
    local byFrame = {}
    for _, e in ipairs(r.elements) do byFrame[e.frame] = e end

    local seen, lines = {}, {}
    local function Add(f)
        if not f or seen[f] then return end
        seen[f] = true
        local e = byFrame[f]
        lines[#lines + 1] = e and InspectLine(e)
            or ((Safe.Call(f, "GetDebugName") or tostring(f)) .. " - |cffffaa00not in the last scan|r (/fa scan)")
    end
    for _, focus in ipairs(GetMouseFoci()) do
        if focus ~= WorldFrame then Add(ns.Fader:RootOf(focus)) end
    end
    for _, e in ipairs(r.elements) do
        if Safe.IsVisible(e.frame) and ns.Fader:IsMouseOver(e.frame) then Add(e.frame) end
    end

    if #lines == 0 then return ns.Print("No UI element under the mouse.") end
    ns.Print("Under the mouse:")
    for _, line in ipairs(lines) do print("  " .. line) end
end

function commands.debug()
    ns.db.debug = not ns.db.debug
    ns.Print("Debug output " .. OnOff(ns.db.debug) .. " (wake reasons, enforced elements)")
end

-- /fa profile                 list, the active one marked
-- /fa profile <name>          activate it
-- /fa profile new <name>      new profile from the defaults, activate it
-- /fa profile copy <name>     copy of the active profile, activate it
-- /fa profile delete <name>
function commands.profile(rest)
    local P = ns.Profiles
    local verb, name = rest:match("^(%S+)%s+(.+)$")
    local ok, err
    if verb == "new" or verb == "copy" then
        ok, err = P:Create(name, verb == "copy")
    elseif verb == "delete" then
        ok, err = P:Delete(name)
    elseif rest ~= "" then
        ok, err = P:Use(rest)
    end
    if rest ~= "" and not ok then return ns.Print(err) end
    local names = {}
    for _, n in ipairs(P:List()) do
        names[#names + 1] = n == P:Active() and ("|cffe6ba66" .. n .. "|r") or n
    end
    ns.Print(L.CMD_PROFILES:format(table.concat(names, ", ")))
end

function commands.icon()
    ns.db.icon.show = not ns.db.icon.show
    ns.SettingsChanged()
    ns.Print(L.CMD_ICON:format(OnOff(ns.db.icon.show)))
end

function commands.minimap()
    local m = Sendit.db.minimap
    m.hide = not m.hide
    ns.SettingsChanged()
    ns.Print(L.CMD_MINIMAP:format(OnOff(not m.hide)))
end

function ns.OpenSettings()
    local O = ns.Options
    local cur = O:Current()
    if cur and cur.module == ns.module then return O:Hide() end
    O:Show("fade.general")
end

Sendit:AddQuickToggle({
    label = function() return ns.L.FADING_QUICK end,
    get = function() return ns.profile and ns.profile.enabled end,
    set = function() commands.toggle() end,
})

function commands.cinema(arg)
    if arg:lower() == "test" then return ns.Cinema:Preview(8) end
    local p = ns.profile
    if arg:lower() == "services" then
        p.cinemaServices = not p.cinemaServices
        ns.SettingsChanged()
        return Say(L.CMD_CINEMA_SERVICES:format(OnOff(p.cinemaServices)))
    end
    if arg:lower() == "camera" then
        p.cinemaCamera = not p.cinemaCamera
        ns.SettingsChanged()
        return Say(L.CMD_CINEMA_CAMERA:format(OnOff(p.cinemaCamera)))
    end
    p.cinema = not p.cinema
    ns.SettingsChanged()
    Say(L.CMD_CINEMA:format(OnOff(p.cinema)) .. (ns.Cinema:HasSpoken() and "" or L.CMD_NO_SPOKEN))
end

function commands.probe()
    local map = _G.Minimap
    if type(map) ~= "table" then return ns.Print("No Minimap.") end
    local root = ns.Fader:RootOf(map)
    ns.Print(("Minimap: alpha %s, faded by us via %s, arrows %s"):format(
        tostring(ns.Safe.Alpha(map)), root == map and "Minimap itself" or tostring(root and ns.Safe.Name(root)),
        ns.Specials:IsActive("Minimap") and "hidden" or "shown"))
    print("  methods: " .. table.concat(ns.MinimapGlyphs:Methods(), ", "))
end

function commands.help(_)
    ns.Print("v" .. ns.version)
    for line in L.HELP:gmatch("[^\n]+") do print("  " .. line) end
end

SLASH_SENDITFADE1 = "/fa"
SLASH_SENDITFADE2 = "/fade"
SlashCmdList.SENDITFADE = function(msg)
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" then return ns.OpenSettings() end
    local fn = commands[cmd] or commands.help
    fn(rest)
end
