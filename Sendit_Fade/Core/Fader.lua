--[[
  Fader: fades the elements Rules allows, with SetAlpha only (allowed on
  protected frames, also in combat; never Show/Hide/reparent).

  Timing: while Triggers reports a wake reason the UI is fully visible;
  `delay` seconds after the last one it fades to `alpha`. Hovering an element
  wakes just that element; so does typing in it (or in an input anchored to
  it, e.g. a chat input under its chat window). An element that just appeared
  stays visible for `delay` seconds.

  Alpha ownership: a fully visible element is never touched. When fading
  starts its current alpha becomes `base` and we set base * cur. Other code
  may keep setting alpha on its own frames; fighting that would flicker:
    - addon frames (not Blizzard, not protected): post-hook SetAlpha and
      rescale the new value in the same frame
    - Blizzard / protected frames (a hook could spread taint): adopt the new
      value; after FIGHT_LIMIT changes in FIGHT_WINDOW the element is
      "contested" and our alpha is re-applied every frame while faded

  Cinema (Cinema.lua): while set, every element fades to 0 except the one
  holding the focus frame and those of the focus addon family (Spoken's
  subtitles live in their own window), also user-excluded elements and with
  fading off.
  Such extra elements carry s.extra.

  Leaving: an element that drops out of the set while faded (cinema ended,
  profile switched, element excluded) is not released at once; it carries
  s.leaving, fades back in and is dropped when fully visible.

  Specials (Specials.lua): handlers for elements that need more than alpha
  once fully faded; they ask IsFullyFaded and may give a hover rect for a
  frame they hid.

  Per-element state s: { frame, e, cur, target, base, visible, hoverUntil,
  canHook, hooked, contested, fights, fightStart, skip, extra, leaving }.
]]
local _, ns = ...

local Fader = {}
ns.Fader = Fader

local Safe, Rules, Triggers = ns.Safe, ns.Rules, ns.Triggers

local TICK = 0.1             -- seconds between condition checks
local CHILD_POLL = 1         -- seconds between "new UIParent children?" checks
local HOVER_LINGER = 1       -- seconds an element stays visible after the mouse left
local MAX_HOVER_AREA = 0.25  -- share of the screen above which IsMouseOver is too coarse
local ALPHA_EPSILON = 0.02
local FIGHT_WINDOW = 3
local FIGHT_LIMIT = 3

local managed = {}  -- frame -> state
local list = {}     -- states, for iteration
local hooked = {}   -- frames with our SetAlpha hook (hooks cannot be removed)
local tickAcc, childAcc, lastChildCount = 0, 0, nil
local wasAwake = true
local cinema = nil  -- { focus = frame or nil } while the cinema mode runs

local function Debug(msg)
    if ns.db.debug then ns.Print("|cffaaaaaa[debug]|r " .. msg) end
end

---------------------------------------------------------------------------
-- Alpha writes
---------------------------------------------------------------------------
local applying = false  -- our own SetAlpha calls must not trigger the hook logic

local function SetOwn(f, a)
    applying = true
    local ok, err = pcall(f.SetAlpha, f, a)
    applying = false
    if not ok then error(err, 0) end
end

local function OnForeignSetAlpha(f, a)
    if applying then return end
    local s = managed[f]
    a = Safe.Value(a)
    if not (s and s.base and a) then return end
    s.base = math.min(1, math.max(0, a))
    SetOwn(f, s.base * s.cur)
end

local function HookAlpha(s)
    if not hooked[s.frame] then
        hooked[s.frame] = true
        hooksecurefunc(s.frame, "SetAlpha", OnForeignSetAlpha)
    end
    s.hooked = true
end

local function Release(s)
    if s.base then
        SetOwn(s.frame, s.base)
        s.base = nil
    end
    s.cur = 1
end

local function Skip(s, why)
    Release(s)
    s.skip = why
    Debug(("skipping %s (%s): %s"):format(s.e.label, s.e.owner, why))
end

---------------------------------------------------------------------------
-- Element set
---------------------------------------------------------------------------
function Fader:Sync(r)
    r = r or ns.Scanner.last
    if not r then return end
    Rules:Refresh()
    local keep = {}
    local enabled = ns.Active()
    if enabled or cinema then
        for _, e in ipairs(r.elements) do
            local _, rule = Rules:Reason(e)
            local extra = rule ~= nil or not enabled
            if (not rule and enabled) or (cinema and rule ~= "builtin") then
                local s = managed[e.frame] or { frame = e.frame, cur = 1, target = 1, hoverUntil = 0 }
                s.e = e
                s.extra = extra
                s.leaving = nil
                s.canHook = e.owner ~= "Blizzard" and not e.protected
                keep[e.frame] = s
            end
        end
    end
    for f, s in pairs(managed) do
        if not keep[f] then
            if s.base and not s.skip then
                s.leaving = true
                keep[f] = s
            else
                Release(s)
            end
        end
    end
    managed = keep
    wipe(list)
    for _, s in pairs(managed) do list[#list + 1] = s end
    lastChildCount = UIParent:GetNumChildren()
end

-- Start (focus frame or false) or end (nil) the cinema look. On the end the
-- extra elements leave: they fade back in, then drop out.
-- keepOwner: elements whose owner starts with it stay visible too.
function Fader:SetCinema(on, focus, keepOwner)
    if on then
        cinema = { focus = focus or nil, keepOwner = keepOwner }
        self:Sync()
    elseif cinema then
        cinema = nil
        self:Sync()
    end
end

-- Whether the element holding frame is faded all the way to 0 and stays
-- there (target 0; a wake raises the target at once).
function Fader:IsFullyFaded(frame)
    local s = managed[self:RootOf(frame) or false]
    return s ~= nil and not s.skip and s.base ~= nil
        and s.target <= ALPHA_EPSILON and s.cur <= ALPHA_EPSILON
end

local function KeptInCinema(s, focus, keep)
    if s.frame == focus then return true end
    return keep ~= nil and s.e.owner:sub(1, #keep) == keep
end

-- Forget all per-element state (skipped elements get another chance).
function Fader:Reset()
    for _, s in ipairs(list) do pcall(Release, s) end
    wipe(managed)
    wipe(list)
    Triggers:Wake("enabled")
    self:Sync()
end

---------------------------------------------------------------------------
-- Queries and changes (options window, commands, overlay)
---------------------------------------------------------------------------
-- -> status text, exclusion rule (nil if included), faded right now
function Fader:Status(e)
    local reason, rule = Rules:Reason(e)
    if reason then return reason, rule, false end
    local L = ns.L
    if not ns.Active() then return L.ST_OFF, nil, false end
    local s = managed[e.frame]
    if s and s.skip then return L.ST_SKIPPED:format(s.skip), nil, false end
    return s and s.contested and L.ST_ENFORCED or L.ST_FADED, nil, true
end

function Fader:State(frame)
    return managed[frame]
end

function Fader:SetExcluded(e, excluded)
    ns.profile.exclude.elements[e.key] = excluded or nil
    self:Sync()
    ns.SettingsChanged()
end

-- owners: one addon name or a list (an addon family).
function Fader:SetAddonExcluded(owners, excluded)
    if type(owners) ~= "table" then owners = { owners } end
    for _, owner in ipairs(owners) do ns.profile.exclude.addons[owner] = excluded or nil end
    self:Sync()
    ns.SettingsChanged()
end

-- An element's own alpha, ignoring our fading (0 = hidden by its owner).
function Fader:IntrinsicAlpha(frame)
    local s = managed[frame]
    if s and s.base then return s.base end
    return Safe.Alpha(frame)
end

-- Keep one element visible for a moment (list hover, highlight).
function Fader:Peek(frame, seconds)
    local s = managed[frame]
    if s then s.hoverUntil = math.max(s.hoverUntil, GetTime() + (seconds or 1)) end
end

-- Keep every element of a kind visible for a moment (chat activity).
-- Inputs are left out: an idle chat input would show as an empty box.
function Fader:PeekKind(kind, seconds)
    local untilT = GetTime() + (seconds or 1)
    for _, s in ipairs(list) do
        if s.e.kind == kind and Safe.Call(s.frame, "GetObjectType") ~= "EditBox" then
            s.hoverUntil = math.max(s.hoverUntil, untilT)
        end
    end
end

-- -> managed, skipped, contested
function Fader:Count()
    local skipped, contested = 0, 0
    for _, s in ipairs(list) do
        if s.skip then skipped = skipped + 1 end
        if s.contested then contested = contested + 1 end
    end
    return #list, skipped, contested
end

---------------------------------------------------------------------------
-- Mouse
---------------------------------------------------------------------------
-- Rectangle test for elements that are small enough for it to mean something.
-- A frame a special handler hid is tested against the rect it had (Specials).
function Fader:IsMouseOver(f)
    local saved = ns.Specials:HoverRect(f)
    local l, b, w, h
    if saved then l, b, w, h = saved[1], saved[2], saved[3], saved[4] else l, b, w, h = Safe.Rect(f) end
    if not w then return false end
    local share = (w * h) / (UIParent:GetWidth() * UIParent:GetHeight())
    if share <= 0 or share >= MAX_HOVER_AREA then return false end
    if saved then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x, y = x / scale, y / scale
        return x >= l and x <= l + w and y >= b and y <= b + h
    end
    return Safe.Call(f, "IsMouseOver") == true
end

-- The top-level element (UIParent child or parentless) a frame belongs to.
function Fader:RootOf(f)
    while f and not Safe.IsForbidden(f) do
        if managed[f] then return f end
        local p = Safe.Parent(f)
        if p == UIParent or p == nil then return f end
        f = p
    end
end

-- Typing: the element holding the keyboard focus stays visible, and so does
-- the element the focused box is anchored to: a chat input placed under a
-- chat window often belongs to another frame tree than the window it serves
-- (Blizzard's edit box under a chat addon's window). Generic, no addon names.
local function MarkTyping(now, linger)
    local get = _G["GetCurrentKeyBoardFocus"]
    if not get then return end
    local ok, box = pcall(get)
    box = ok and Safe.Value(box) or nil
    if type(box) ~= "table" or Safe.IsForbidden(box) then return end
    local untilT = now + linger
    -- A focused input that is an element itself is handed back fully visible
    -- at once. Its owner sets its alpha on activation (Blizzard's "im" chat
    -- style: 0.35 idle, 1 active); a running fade overwrote that, and
    -- restoring the remembered idle value left the input pale while typing.
    local own = managed[box]
    if own and own.base then
        own.base, own.cur, own.target = nil, 1, 1
        SetOwn(box, 1)
    end
    local function Mark(f)
        local s = managed[Fader:RootOf(f) or false]
        if s then s.hoverUntil = math.max(s.hoverUntil, untilT) end
    end
    Mark(box)
    local okPoint, _, rel = pcall(box.GetPoint, box, 1)
    rel = okPoint and Safe.Value(rel) or nil
    if type(rel) == "table" and rel ~= UIParent and not Safe.IsForbidden(rel) then Mark(rel) end
end

local function MarkHover(now)
    local untilT = now + HOVER_LINGER
    for _, focus in ipairs(GetMouseFoci()) do  -- mouse-enabled frames under the cursor
        local s = managed[Fader:RootOf(focus) or false]
        if s then s.hoverUntil = untilT end
    end
    for _, s in ipairs(list) do  -- elements without mouse handling (e.g. tracker text)
        local hoverable = s.visible or ns.Specials:HoverRect(s.frame) ~= nil
        if hoverable and s.hoverUntil < untilT and Fader:IsMouseOver(s.frame) then
            s.hoverUntil = untilT
        end
    end
end

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------
local function CheckForeign(s, now)
    local a = Safe.Alpha(s.frame)
    if not a or math.abs(a - s.base * s.cur) <= ALPHA_EPSILON then return end
    if now - (s.fightStart or 0) > FIGHT_WINDOW then s.fightStart, s.fights = now, 0 end
    s.fights = s.fights + 1
    if s.fights >= FIGHT_LIMIT then
        s.contested = true
        Debug(("enforcing alpha on %s (%s)"):format(s.e.label, s.e.owner))
        return
    end
    s.base = s.cur > ALPHA_EPSILON and math.min(1, a / s.cur) or a
    SetOwn(s.frame, s.base * s.cur)
end

local function Evaluate(now)
    local p = ns.profile
    local reason = Triggers:Active(now)
    if reason then Triggers.lastWake, Triggers.reason = now, reason end
    if p.triggers.mouseover then MarkHover(now) end
    if p.triggers.typing then MarkTyping(now, p.delay) end  -- linger: read what you sent

    local awake = now - Triggers.lastWake < p.delay
    if awake ~= wasAwake then
        wasAwake = awake
        Debug(awake and ("UI awake: " .. Triggers.reason) or "UI fading")
    end

    local focus = cinema and cinema.focus and Fader:RootOf(cinema.focus)
    local keepOwner = cinema and cinema.keepOwner
    for _, s in ipairs(list) do
        if not s.skip then
            local visible = Safe.IsVisible(s.frame)
            if visible and not s.visible then
                s.hoverUntil = math.max(s.hoverUntil, now + p.delay)  -- just appeared
            end
            s.visible = visible
            if s.leaving then
                s.target = 1
            elseif cinema then
                s.target = KeptInCinema(s, focus, keepOwner) and 1 or 0
            elseif s.extra then
                s.target = 1
            else
                s.target = (awake or s.hoverUntil > now) and 1 or p.alpha
            end
            if visible and s.base and s.cur == s.target and not s.contested then CheckForeign(s, now) end
        end
    end
end

-- A leaving element is done once fully visible (or hidden: nothing to show).
local function Drop(s)
    Release(s)
    managed[s.frame] = nil
    s.dropped = true
end

local function Animate(elapsed)
    local p = ns.profile
    local inStep = elapsed / math.max(p.fadeIn, 0.01)
    local outStep = elapsed / math.max(p.fadeOut, 0.01)
    local dropped = false
    for _, s in ipairs(list) do
        if s.leaving and (not s.visible or s.skip) then
            Drop(s)
            dropped = true
        end
        local moving = s.visible and not s.skip and s.cur ~= s.target
        if moving and not s.base then
            s.base = Safe.Alpha(s.frame)
            if not s.base then
                Skip(s, "secret alpha")
                moving = false
            elseif s.canHook and not s.hooked then
                HookAlpha(s)
            end
        end
        if moving then
            if s.target > s.cur then
                s.cur = math.min(s.target, s.cur + inStep)
            else
                s.cur = math.max(s.target, s.cur - outStep)
            end
            if s.cur >= 1 and s.leaving then
                Drop(s)
                dropped = true
            elseif s.cur >= 1 then
                Release(s)  -- fully visible again: hand alpha back
            else
                SetOwn(s.frame, s.base * s.cur)
            end
        elseif s.contested and s.base and s.visible then
            SetOwn(s.frame, s.base * s.cur)
        end
    end
    if dropped then
        for i = #list, 1, -1 do
            if list[i].dropped then table.remove(list, i) end
        end
    end
end

local function Step(elapsed)
    tickAcc = tickAcc + elapsed
    if tickAcc >= TICK then
        tickAcc = 0
        Evaluate(GetTime())
    end
    childAcc = childAcc + elapsed
    if childAcc >= CHILD_POLL then
        childAcc = 0
        local n = UIParent:GetNumChildren()
        if lastChildCount and n ~= lastChildCount then
            lastChildCount = n
            ns:RequestScan()
        end
    end
    Animate(elapsed)
end

-- An error must not repeat every frame: restore everything, report once.
local function Pause(err)
    for _, s in ipairs(list) do pcall(Release, s) end
    wipe(managed)
    wipe(list)
    ns.Print("|cffff5555Fading paused after an error|r (/fa on to retry):")
    print("  " .. tostring(err))
end

local driver = CreateFrame("Frame")
ns.ownFrames[driver] = true
driver:SetScript("OnUpdate", function(_, elapsed)
    if not ns.profile or #list == 0 then return end
    local ok, err = pcall(Step, elapsed)
    if not ok then Pause(err) end
end)
