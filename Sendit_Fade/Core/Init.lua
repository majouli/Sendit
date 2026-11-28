--[[
  Init: Fade's namespace, module registration, event dispatch (an event X calls ns:X(...)).
  ns.profile = the module's profile section (everything about fading), ns.db = its account section
  (toggle icon, overlay); ns.Theme / Widgets / Options / Profiles are the core's.
]]
local ADDON, ns = ...
local Sendit = Sendit

ns.name = ADDON
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.ownFrames = Sendit.ownFrames  -- frames of the suite: never scanned or faded
ns.ICON = "Interface\\AddOns\\Sendit_Fade\\Media\\Icon"
ns.commands = {}
ns.Theme, ns.Widgets, ns.Options, ns.Profiles = Sendit.Theme, Sendit.Widgets, Sendit.Options, Sendit.Profiles
ns.Copy, ns.Merge = Sendit.Copy, Sendit.Merge
ns.OnSettingsChanged, ns.SettingsChanged = Sendit.OnSettingsChanged, Sendit.SettingsChanged

local PREFIX = "|cffe6ba66Sendit Fade|r: "
function ns.Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

ns.defaults = {  -- account section
    icon     = { show = true, locked = false, alpha = 0.4 },  -- on-screen toggle; point set on drag
    overlay  = { maxSize = 0.5 },  -- Show on screen: hide boxes above this share of the screen; point set on drag
    announce = true,  -- login message
    debug    = false,
}

ns.profileDefaults = {
    enabled  = true,
    alpha    = 0,    -- alpha of faded elements
    delay    = 5,    -- seconds without a wake trigger before fading
    fadeOut  = 1.0,  -- seconds for a full fade out
    fadeIn   = 0.2,  -- seconds for a full fade in
    triggers = {
        combat = true, target = true, health = true,
        casting = true, mouseover = true,
        typing = true,  -- the element you type in (e.g. chat with its input open)
        chatGroup = true,  -- party / raid / instance chat shows the chat for a moment
        chatLoot = true,   -- loot and money messages show the chat for a moment
    },
    cinema       = true,  -- film look while Spoken narrates (Cinema.lua)
    cinemaCamera = true,  -- ... with a slow camera orbit
    cinemaServices = false,  -- ... also at vendors, bankers, flight masters
    cinemaWalkAway = true,   -- ... ends when walking away from the NPC (Leash.lua)
    exclude = {
        elements = {},  -- [element key] = true
        addons   = {},  -- [owner] = true
        patterns = {},  -- [lowercase text] = true (/fa exclude <text>)
    },
}

-- switched off in the sidebar: everything visible at once, the reload stops the code
ns.switchedOff = false
Sendit.OnModuleSwitch(function(addon, on)
    if addon ~= ADDON then return end
    ns.switchedOff = not on
    if ns.Fader and ns.Scanner and ns.Scanner.last then ns.Fader:Sync() end
    Sendit.SettingsChanged()
end)

function ns.Active()
    return ns.profile ~= nil and ns.profile.enabled == true and not ns.switchedOff
end

ns.module = Sendit:RegisterModule({
    addon = "Sendit_Fade",
    key = "fade",
    title = "Fade",
    icon = ns.ICON,
    defaults = ns.profileDefaults,
    accountDefaults = ns.defaults,
    status = function()
        if not ns.profile then return nil end
        if not ns.profile.enabled then return ns.L.OFF end
        return ns.L.FADED:format((ns.Fader:Count()))
    end,
})

local function Bind()
    ns.profile, ns.db = ns.module.profile, ns.module.db
end
-- bound as soon as the core has its saved variables (its first SettingsChanged may come first)
Sendit.OnReady(Bind)

local events = CreateFrame("Frame")
ns.ownFrames[events] = true
ns.eventFrame = events

Sendit.OnProfile(function()
    Bind()
    ns.Fader:Sync()
end)
events:SetScript("OnEvent", function(_, event, ...)
    local handler = ns[event]
    if handler then handler(ns, ...) end
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

function ns:ADDON_LOADED(name)
    if name ~= ADDON then
        if ns.ready then ns:RequestScan() end  -- load-on-demand UI
        return
    end
    Sendit.OnReady(function()
        Bind()
        ns.SettingsChanged()
    end)
end

function ns:Rescan()
    local r = ns.Scanner:Scan()
    ns.Fader:Sync(r)
    ns.SettingsChanged()
    return r
end

-- debounced: frames appear in bursts
local scanPending = false
function ns:RequestScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(2, function()
        scanPending = false
        ns:Rescan()
    end)
end

function ns:PLAYER_ENTERING_WORLD()
    events:UnregisterEvent("PLAYER_ENTERING_WORLD")  -- first load only
    C_Timer.After(3, function()  -- let addons finish building their UI
        ns.ready = true
        ns.Triggers:Refresh()
        ns.Triggers:Wake("login")
        local r = ns:Rescan()
        if ns.db.announce then
            ns.Print(ns.L.LOGIN_LINE:format(
                r.total, (ns.Fader:Count()), ns.Profiles:Active()))
        end
    end)
end
