--[[
  Specials: elements that need more than alpha once fully faded. A handler { name, Frame(), Enter(frame),
  Leave(frame), HoverRect(frame) } is called when its frame is fully faded and when that ends
  (Enter / Leave return false to retry). Own ticker, also with fading off; an erroring handler is
  left and switched off with one message.
]]
local _, ns = ...

local Specials = {}
ns.Specials = Specials

local TICK = 0.1

local handlers = {}

function Specials:Register(handler)
    handlers[#handlers + 1] = { handler = handler, active = false }
end

local function Debug(msg)
    if ns.db and ns.db.debug then ns.Print("|cffaaaaaa[special]|r " .. msg) end
end

local function Call(h, method, frame)
    local ok, r = pcall(h.handler[method], h.handler, frame)
    if ok then return r end
    if not h.broken then
        ns.Print("|cffff5555" .. ns.L.SPECIAL_OFF:format(h.handler.name) .. "|r " .. tostring(r))
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
