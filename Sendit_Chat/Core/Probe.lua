--[[
  Probe: /chat probe - records the chat input's alpha and who could fade it for 12 s (read-only),
  saved to SenditDB.account.chat.probe.
]]
local _, ns = ...
local Safe = ns.Safe

local Probe = {}
ns.Probe = Probe

local DURATION, STEP = 12, 0.1

local function Name(f)
    if type(f) ~= "table" then return tostring(f) end
    local n = Safe.Str(Safe.Call(f.GetName, f))
    return n or (f == UIParent and "UIParent" or "<anonymous>")
end

local function Num(v)
    v = Safe.Num(v)
    return v and ("%.2f"):format(v) or "?"
end

local function Sample(eb)
    local parent = Safe.Call(eb.GetParent, eb)
    return ("own %s  effective %s  parent(%s) %s  shown %s"):format(
        Num(Safe.Call(eb.GetAlpha, eb)), Num(Safe.Call(eb.GetEffectiveAlpha, eb)),
        Name(parent), Num(parent and Safe.Call(parent.GetAlpha, parent)),
        tostring(Safe.Call(eb.IsShown, eb)))
end

local function Out(lines, text)
    lines[#lines + 1] = text
    ns.Print(text)
end

function Probe.Run()
    local lines = {}
    local cvar = _G["GetCVar"]
    Out(lines, ("probe: chatStyle=%s, press Enter now and keep typing (%d s)"):format(
        tostring(cvar and cvar("chatStyle")), DURATION))
    local start = GetTime()
    local last = {}
    local function Tick()
        local t = GetTime() - start
        local get = _G["GetCurrentKeyBoardFocus"]
        local focus = get and Safe.Call(get)
        for _, eb in ipairs(ns.Mirror.EditBoxes()) do
            local s = Sample(eb)
            if s ~= last[eb] and (Safe.Call(eb.IsShown, eb) or last[eb]) then
                last[eb] = s
                local ignore = Safe.Call(eb.IsIgnoringParentAlpha, eb)
                Out(lines, ("%4.1fs %s%s: %s  ignoreParent %s"):format(t, Name(eb),
                    focus == eb and " [focus]" or "", s, tostring(ignore)))
            end
        end
        if t < DURATION then
            C_Timer.After(STEP, Tick)
        else
            Out(lines, "probe: done")
            ns.acct.probe = lines
        end
    end
    C_Timer.After(STEP, Tick)
end
