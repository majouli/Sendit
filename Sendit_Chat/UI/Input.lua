--[[
  Input: the main chat input is Blizzard's own chat edit box, placed under
  Sendit Chat's main window and restyled.

  Why Blizzard's box: it does slash commands, chat types, channels, the
  reply target and its history, and its sends stay secure. In a chat
  lockdown (boss fights) the client refuses sends from addon code, so an
  own main input would silently swallow messages there.

  Only plain setters are used on the box (points, font, size, region alpha)
  plus new regions of our own. No script hooks and no field writes: those
  taint the box's chat type and every later send.

  Input.Anchor()   re-place and restyle (main window moved, resized, font)
  Input.OnWhisperMode(fn)   fn(target, bn) when the box switches to a whisper
                   WHILE the user types in it ("/w Bob " -> WHISPER, Bob).
                   Read from the box's attributes in the same poll; opening
                   the box already whispering (R, sticky whisper) is no switch.
]]
local _, ns = ...
local T, Mirror, Safe = ns.Theme, ns.Mirror, ns.Safe

local Input = {}
ns.Input = Input

local ours = {}     -- eb -> { textures we created }
local ourSet = {}   -- texture -> true

local function Regions(eb)
    local ok, regions = pcall(function() return { eb:GetRegions() } end)
    return ok and regions or {}
end

local function Skin(eb)
    for _, r in ipairs(Regions(eb)) do
        if not ourSet[r] and r.GetObjectType and r:GetObjectType() == "Texture" then
            local a = Safe.Call(r.GetAlpha, r)
            if a == nil or Safe.IsSecret(a) or a ~= 0 then pcall(r.SetAlpha, r, 0) end
        end
    end
    if ours[eb] then return end
    local bg = T.Tex(eb, "BACKGROUND", "bg", 0.9, -8)
    bg:SetPoint("TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", 0, 0)
    local line = T.Tex(eb, "BORDER", "accent", 0.55)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    ours[eb] = { bg = bg, line = line }
    ourSet[bg], ourSet[line] = true, true
end

-- Our ground shows only while the box is in use. In the "im" chat style
-- Blizzard keeps an idle box shown at low alpha; without this our ground
-- would stay behind as a dim bar. Polled from our own frame: no hooks on
-- the Blizzard box (they taint its sends).
local shownState = {}  -- eb -> true / false as last applied
local function UpdateGround(eb)
    local skin = ours[eb]
    if not skin then return end
    local on = Safe.Call(eb.HasFocus, eb) == true
    if shownState[eb] == on then return end
    shownState[eb] = on
    skin.bg:SetShown(on)
    skin.line:SetShown(on)
end
Input._UpdateGround = UpdateGround

local whisperFns = {}
function Input.OnWhisperMode(fn) whisperFns[#whisperFns + 1] = fn end

local WHISPERS = { WHISPER = true, BN_WHISPER = true }
local modeState = {}  -- eb -> { focus, chatType }
local function WatchMode(eb)
    local focus = Safe.Call(eb.HasFocus, eb) == true
    local chatType = focus and Safe.Str(Safe.Call(eb.GetAttribute, eb, "chatType")) or nil
    local last = modeState[eb]
    modeState[eb] = { focus = focus, chatType = chatType }
    if not (focus and last and last.focus) then return end
    if WHISPERS[chatType] and not WHISPERS[last.chatType] then
        local target = Safe.Str(Safe.Call(eb.GetAttribute, eb, "tellTarget"))
        if target and target ~= "" then
            for _, fn in ipairs(whisperFns) do fn(target, chatType == "BN_WHISPER") end
        end
    end
end
Input._WatchMode = WatchMode

local poll = CreateFrame("Frame")
local acc = 0
poll:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.05 or not ns.active then return end
    acc = 0
    for eb in pairs(ours) do WatchMode(eb) end
    for eb in pairs(ours) do UpdateGround(eb) end
end)

local function Font(eb)
    local size = ns.db.fontSize
    pcall(T.SetFont, eb, size, true)
    for _, key in ipairs({ "header", "headerSuffix", "prompt" }) do
        local fs = eb[key]
        if type(fs) == "table" and fs.SetFontObject then pcall(T.SetFont, fs, size, true) end
    end
    pcall(eb.SetHeight, eb, size + 16)
end

function Input.Anchor()
    local main = ns.Windows and ns.Windows.Main()
    if not main then return end
    for _, eb in ipairs(Mirror.EditBoxes()) do
        pcall(eb.ClearAllPoints, eb)
        pcall(eb.SetPoint, eb, "TOPLEFT", main.frame, "BOTTOMLEFT", 0, -3)
        pcall(eb.SetPoint, eb, "TOPRIGHT", main.frame, "BOTTOMRIGHT", 0, -3)
        Skin(eb)
        Font(eb)
    end
end

local function Loop()
    if not ns.active then return end
    Input.Anchor()  -- Blizzard re-anchors the box in some layout passes
    C_Timer.After(2, Loop)
end

ns.OnReady(function()
    Loop()
    ns.OnChanged(Input.Anchor)
end)
