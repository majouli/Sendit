--[[
  Cinema: a film look while the optional addon Spoken narrates (its public API only). While a clip of
  SOURCES plays: everything but Spoken's elements fades to 0 (Fader:SetCinema), black bars to 2.39:1,
  and (cinemaCamera) the view is saved in VIEW_SLOT, zoomed out and slowly orbited, restored at the end.
  Ends LINGER s after the last clip, at once on combat or Escape (then off until Spoken is quiet).
  Moving stops the orbit, turning the camera hands it over. No film for service NPCs unless
  cinemaServices; walking away (cinemaWalkAway, Leash) ends an NPC's line.
]]
local _, ns = ...

local Cinema = {}
ns.Cinema = Cinema

local SOURCES = { quests = true, gossip = true, places = true, readables = true }
local NPC_SOURCES = { quests = true, gossip = true }  -- spoken by someone you stand at
local RATIO = 2.39        -- picture aspect between the bars (film scope)
local BAR_TIME = 0.8      -- seconds for the bars to slide in or out
local LINGER = 1.5        -- seconds of silence before the cinema ends
local VIEW_SLOT = 5       -- SaveView slot borrowed for the restore
local ZOOM_OUT = 4        -- yards the camera backs off
local ORBIT_SPEED = 0.03  -- share of cameraYawMoveSpeed (~5 degrees/s at the default)
local LEASH_TICK = 0.2    -- seconds between walk-away checks

local active, dismissed, preview = false, false, false
local camera = nil  -- nil | "orbit" | "still" (orbit stopped, restore at end) | "user" (no restore)
local stopToken = 0
local bars, top, bottom
local barShare, barDir = 0, 0  -- 0..1 slide progress, +1 in / -1 out
local leashAcc = 0

local function Call(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
end

local function Spoken()
    ---@diagnostic disable-next-line: undefined-field
    local S = _G.Spoken  -- optional addon; its public API only
    if type(S) == "table" and type(S.IsCompatible) == "function" and S:IsCompatible(1)
        and type(S.RegisterCallback) == "function" then
        return S
    end
end

local function Debug(msg)
    if ns.db and ns.db.debug then ns.Print("|cffaaaaaa[cinema]|r " .. msg) end
end

local function BarHeight()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if not (w and h) or w <= 0 then return 0 end
    return math.max(0, (h - w / RATIO) / 2)
end

local function LayoutBars()
    local p = barShare * barShare * (3 - 2 * barShare)  -- smoothstep
    local hgt = math.max(BarHeight() * p, 0.001)        -- 0 would unset the height
    top:SetHeight(hgt)
    bottom:SetHeight(hgt)
end

local function OnUpdate(_, elapsed)
    if barDir ~= 0 then
        barShare = math.min(1, math.max(0, barShare + barDir * elapsed / BAR_TIME))
        LayoutBars()
        if barShare == 0 and barDir < 0 then
            barDir = 0
            bars:Hide()
        elseif barShare == 1 then
            barDir = 0
        end
    end
    if camera == "orbit" and Call("IsMouselooking") then
        Call("MoveViewLeftStop")
        camera = "user"
        Debug("camera handed to the player")
    end
    leashAcc = leashAcc + elapsed
    if active and leashAcc >= LEASH_TICK then
        leashAcc = 0
        if ns.Leash:Exceeded() then Cinema:Stop("walked away", true) end
    end
end

local function CreateBars()
    -- named for UISpecialFrames: Escape hides it, which dismisses
    bars = CreateFrame("Frame", "SenditFadeCinemaBars", UIParent)
    ns.ownFrames[bars] = true
    bars:SetAllPoints(UIParent)
    bars:SetFrameStrata("BACKGROUND")
    bars:SetFrameLevel(0)
    bars:EnableMouse(false)
    top = bars:CreateTexture(nil, "BACKGROUND")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    bottom = bars:CreateTexture(nil, "BACKGROUND")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    for _, t in ipairs({ top, bottom }) do t:SetColorTexture(0, 0, 0, 1) end
    bars:Hide()
    bars:SetScript("OnUpdate", OnUpdate)
    -- only our own frame being hidden counts: a hidden UIParent (Alt+Z) leaves IsShown true
    bars:SetScript("OnHide", function()
        if bars:IsShown() then return end
        barShare, barDir = 0, 0
        if active then Cinema:Stop("escape", true) end
    end)
    tinsert(UISpecialFrames, "SenditFadeCinemaBars")
end

local function CameraStart()
    if not ns.profile.cinemaCamera or Call("IsMouselooking") or Call("IsPlayerMoving") then return end
    if type(_G.SaveView) ~= "function" or type(_G.SetView) ~= "function" then return end
    Call("SaveView", VIEW_SLOT)
    Call("CameraZoomOut", ZOOM_OUT)
    Call("MoveViewLeftStart", ORBIT_SPEED)
    camera = "orbit"
end

local function CameraStop()
    if camera == "orbit" then Call("MoveViewLeftStop") end
    if camera == "orbit" or camera == "still" then Call("SetView", VIEW_SLOT) end
    camera = nil
end

function Cinema:IsActive() return active end

function Cinema:Start(why)
    stopToken = stopToken + 1  -- cancels a pending linger stop
    if active then return end
    active = true
    Debug("start: " .. tostring(why))
    if not bars then CreateBars() end
    local S = Spoken()
    local focus = S and type(S.GetPlayerFrame) == "function" and select(2, pcall(S.GetPlayerFrame, S))
    ns.Fader:SetCinema(true, type(focus) == "table" and focus or nil, "Spoken")
    bars:Show()
    barDir = 1
    CameraStart()
    if NPC_SOURCES[why] and ns.profile.cinemaWalkAway then ns.Leash:Start() end
end

-- dismissed: off until Spoken has gone quiet (only a running film can be dismissed)
function Cinema:Stop(why, dismiss)
    if not active then return end
    if dismiss then dismissed = true end
    active, preview = false, false
    Debug("stop: " .. tostring(why))
    ns.Leash:Stop()
    CameraStop()
    ns.Fader:SetCinema(nil)
    if bars:IsShown() then barDir = -1 end
end

local function StopSoon(why)
    stopToken = stopToken + 1
    local token = stopToken
    C_Timer.After(LINGER, function()
        if token ~= stopToken then return end
        local S = Spoken()
        local playing = S and type(S.GetNowPlaying) == "function" and select(2, pcall(S.GetNowPlaying, S))
        if playing and not preview then return end  -- a clip of another source keeps going
        dismissed = false
        Cinema:Stop(why)
    end)
end

function Cinema:Preview(seconds)
    dismissed = false
    self:Start("preview")
    preview = true
    stopToken = stopToken + 1
    local token = stopToken
    C_Timer.After(seconds or 8, function()
        if token == stopToken then self:Stop("preview end") end
    end)
end

local function SourceOf(clip)
    local src = type(clip) == "table" and clip.source
    return type(src) == "table" and src.key or nil
end

-- no film for service NPCs unless cinemaServices; the menu test only for gossip lines
local function SkipService(key)
    if ns.profile.cinemaServices then return false end
    return ns.Services:IsWindowOpen() or key == "gossip" and ns.Services:IsServiceGossip()
end

local function OnClipStarted(clip)
    local key = SourceOf(clip)
    if not SOURCES[key] then return end
    if not active and SkipService(key) then
        Debug("service dialog: no cinema")
        return
    end
    if active then
        stopToken = stopToken + 1
        return
    end
    if not ns.profile.cinema or dismissed or InCombatLockdown() then return end
    Cinema:Start(key)
end

local function OnClipStopped()
    if active and not preview then StopSoon("narration ended") end
end

local function OnQueueEmpty()
    if active and not preview then
        StopSoon("queue empty")
    else
        dismissed = false
    end
end

local hooked = false
local function HookSpoken()
    if hooked then return end
    local S = Spoken()
    if not S then return end
    hooked = true
    S:RegisterCallback("CLIP_STARTED", OnClipStarted)
    S:RegisterCallback("CLIP_STOPPED", OnClipStopped)
    S:RegisterCallback("QUEUE_EMPTY", OnQueueEmpty)
end

function Cinema:HasSpoken()
    return Spoken() ~= nil
end

local ev = CreateFrame("Frame")
ns.ownFrames[ev] = true
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        HookSpoken()
    elseif event == "ADDON_LOADED" then
        HookSpoken()
    elseif event == "PLAYER_REGEN_DISABLED" then
        Cinema:Stop("combat", true)
    elseif event == "PLAYER_STARTED_MOVING" and camera == "orbit" then
        Call("MoveViewLeftStop")
        camera = "still"
        Debug("orbit stopped: moving")
    end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_STARTED_MOVING" }) do
    pcall(ev.RegisterEvent, ev, e)
end

-- the greeting may start the film a moment before the window opens
ns.Services:OnWindowOpen(function()
    if not ns.profile.cinemaServices then Cinema:Stop("service window", true) end
end)

ns.OnSettingsChanged(function()
    if active and ns.profile and not ns.profile.cinema and not preview then Cinema:Stop("turned off") end
end)
