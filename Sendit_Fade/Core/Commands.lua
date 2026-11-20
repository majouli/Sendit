--[[
  Commands: /fa (/fade) - no arguments opens Fade's pages; profiles are the suite's. Each ns.commands
  entry takes the rest of the line.
]]
local _, ns = ...

local commands = ns.commands
local Safe = ns.Safe

local function OnOff(v) return v and "|cff6bd99aon|r" or "|cfff57373off|r" end

local function Changed()
    ns.Fader:Sync()
    ns.SettingsChanged()
end

local function Say(text) ns.Print(text .. "  (profile " .. ns.Profiles:Active() .. ")") end

local function FadedCount()
    return (ns.Fader:Count())
end

function commands.toggle()
    ns.profile.enabled = not ns.profile.enabled
    if ns.profile.enabled then ns.Fader:Reset() end
    Changed()
    ns.Print("Fading " .. OnOff(ns.profile.enabled))
end

-- always restarts the fader (recovers from a paused error)
function commands.on()
    ns.profile.enabled = true
    ns.Fader:Reset()
    Changed()
    ns.Print("Fading " .. OnOff(true))
end

function commands.off()
    if ns.profile.enabled then commands.toggle() end
end

function commands.alpha(v)
    v = tonumber(v)
    if not v or v < 0 or v > 1 then return ns.Print("Usage: /fa alpha <0-1>") end
    ns.profile.alpha = v
    Changed()
    Say("Faded alpha: " .. v)
end

function commands.delay(v)
    v = tonumber(v)
    if not v or v < 0 then return ns.Print("Usage: /fa delay <seconds>") end
    ns.profile.delay = v
    Changed()
    Say("Fade delay: " .. v .. "s")
end

function commands.speed(rest)
    local out, inn = rest:match("^(%S+)%s*(%S*)$")
    out, inn = tonumber(out), tonumber(inn)
    if not out then return ns.Print("Usage: /fa speed <fade-out seconds> [fade-in seconds]") end
    local p = ns.profile
    p.fadeOut = out
    if inn then p.fadeIn = inn end
    Changed()
    Say(("Fade out %.2fs, fade in %.2fs"):format(p.fadeOut, p.fadeIn))
end

function commands.trigger(name)
    local t = ns.profile.triggers
    name = name:lower()
    if t[name] == nil then
        local parts = {}
        for k, v in pairs(t) do parts[#parts + 1] = k .. " " .. OnOff(v) end
        table.sort(parts)
        return Say("Triggers: " .. table.concat(parts, ", ") .. "  (toggle: /fa trigger <name>)")
    end
    t[name] = not t[name]
    Changed()
    Say(("Trigger %s: %s"):format(name, OnOff(t[name])))
end

function commands.exclude(text)
    local patterns = ns.profile.exclude.patterns
    text = text:lower()
    if text == "" then
        local t = {}
        for k in pairs(patterns) do t[#t + 1] = k end
        table.sort(t)
        return Say("Excluded patterns: " .. (#t > 0 and table.concat(t, ", ") or "none"))
    end
    patterns[text] = true
    Changed()
    Say(("Excluding everything matching '%s' (%d elements faded now)"):format(text, FadedCount()))
end

function commands.include(text)
    local patterns = ns.profile.exclude.patterns
    text = text:lower()
    if not patterns[text] then return Say(("'%s' is not an excluded pattern."):format(text)) end
    patterns[text] = nil
    Changed()
    Say(("Pattern '%s' removed (%d elements faded now)"):format(text, FadedCount()))
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
    ns.Print("Profiles: " .. table.concat(names, ", ") .. "  (/fa profile <name> | new | copy | delete <name>)")
end

function commands.icon()
    ns.db.icon.show = not ns.db.icon.show
    ns.SettingsChanged()
    ns.Print("Toggle icon " .. OnOff(ns.db.icon.show))
end

function commands.minimap()
    local m = Sendit.db.minimap
    m.hide = not m.hide
    ns.SettingsChanged()
    ns.Print("Sendit minimap button " .. OnOff(not m.hide))
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
        return Say("Cinema at vendors, bankers, flight masters " .. OnOff(p.cinemaServices))
    end
    if arg:lower() == "camera" then
        p.cinemaCamera = not p.cinemaCamera
        ns.SettingsChanged()
        return Say("Cinema camera orbit " .. OnOff(p.cinemaCamera))
    end
    p.cinema = not p.cinema
    ns.SettingsChanged()
    Say("Cinema while Spoken narrates " .. OnOff(p.cinema)
        .. (ns.Cinema:HasSpoken() and "" or " (Spoken not loaded)"))
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
    print("  /fa                  - open the settings")
    print("  /fa on | off         - enable / disable fading")
    print("  /fa status           - current settings")
    print("  /fa alpha <0-1>      - alpha of faded elements")
    print("  /fa delay <s>        - seconds until the UI fades")
    print("  /fa speed <out> [in] - fade durations in seconds")
    print("  /fa trigger [name]   - toggle a wake trigger (no name: list)")
    print("  /fa exclude [text]   - never fade elements matching text (no text: list)")
    print("  /fa include <text>   - remove such a pattern")
    print("  /fa scan | list [text] - rescan / list detected elements")
    print("  /fa show             - outline all elements on screen, click one to find it")
    print("  /fa inspect          - what happens to the element under the mouse")
    print("  /fa profile [name]   - list / activate profiles (new|copy|delete <name>)")
    print("  /fa cinema [camera|services|test] - toggle the cinema look / its camera orbit /")
    print("                       film at service NPCs, or preview it")
    print("  /fa icon             - show / hide the on-screen toggle icon")
    print("  /fa minimap          - show / hide the Sendit minimap button")
    print("  /fa debug            - toggle debug output")
    print("  /fa probe            - minimap arrow diagnostics")
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
