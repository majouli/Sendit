--[[
  Specials: elements that need more than alpha once they are fully faded.

  Some things on screen ignore frame alpha (e.g. what the engine draws on the
  minimap). A handler for such a case registers here and gets called when
  its frame becomes fully faded (Fader:IsFullyFaded: target and alpha 0) and
  when that ends. Every special case lives in its own module as a handler;
  nothing about it leaks into the Fader.

  Handler contract (all functions get the handler as self):
    name               shown in debug output
    Frame()            -> the frame to watch, or nil (not there now)
    Enter(frame)       hide what alpha cannot; -> true when done, false = retry
                       next tick (e.g. a protected frame in combat)
    Leave(frame)       undo Enter exactly; -> true when done, false = retry
    HoverRect(frame)   optional; while entered, { l, b, w, h } to test the
                       mouse against when Enter took the frame's own area

  Runs on its own ticker, also with fading off or paused: a frame that is no
  longer faded is always left. A handler that errors is left (best effort)
  and switched off with one message.
]]
local _, ns = ...

local Specials = {}
ns.Specials = Specials

local TICK = 0.1

local handlers = {}  -- { handler, active, frame, broken }

function Specials:Register(handler)
    handlers[#handlers + 1] = { handler = handler, active = false }
end

local function Debug(msg)
    if ns.db and ns.db.debug then ns.Print("|cffaaaaaa[special]|r " .. msg) end
end

-- Calls handler:method(frame); -> its result, or nil after an error.
local function Call(h, method, frame)
    local ok, r = pcall(h.handler[method], h.handler, frame)
    if ok then return r end
    if not h.broken then
        ns.Print(("|cffff5555%s switched off after an error:|r %s"):format(h.handler.name, tostring(r)))
    end
    h.broken = true
end

local function Step(h)
    local frame = h.active and h.frame or h.handler:Frame()
    local want = frame ~= nil and not h.broken and ns.profile ~= nil and ns.Fader:IsFullyFaded(frame)
    if want == h.active then return end
    if want then
        if Call(h, "Enter", frame) then
            h.active, h.frame = true, frame
            Debug(h.handler.name .. " entered")
        end
    elseif Call(h, "Leave", h.frame) or h.broken then
        h.active, h.frame = false, nil
        Debug(h.handler.name .. " left")
    end
end

function Specials:Update()
    for _, h in ipairs(handlers) do Step(h) end
end

-- The rect to test the mouse against for frame, if a handler took its area.
function Specials:HoverRect(frame)
    for _, h in ipairs(handlers) do
        if h.active and h.frame == frame and h.handler.HoverRect then
            return h.handler:HoverRect(frame)
        end
    end
end

function Specials:IsActive(name)
    for _, h in ipairs(handlers) do
        if h.handler.name == name then return h.active end
    end
    return false
end

local acc = 0
local driver = CreateFrame("Frame")
ns.ownFrames[driver] = true
driver:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < TICK then return end
    acc = 0
    Specials:Update()
end)
