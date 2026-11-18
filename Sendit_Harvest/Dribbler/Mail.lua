local _, ns = ...

local Mail = {}
ns.DribblerMail = Mail

local Session = ns.DribblerSession
local Plain = ns.Plain
local STEP = 0.4
local ATTACHMENTS = 12
local MAX_TAKES = 200

local SAME_TRIES = 3
local open, running, taken = false, false, 0
local inFlight, last, same = {}, nil, 0
local listeners = {}

function Mail.OnChange(fn) listeners[#listeners + 1] = fn end
local function Changed() for _, fn in ipairs(listeners) do fn() end end

local function Wanted()
    local s = Session.Current()
    if not s or not s.active then return {} end
    local want = {}
    for id, n in pairs(s.owned) do
        local missing = n - (C_Item.GetItemCount(id) or 0) - (inFlight[id] or 0)
        if missing > 0 then want[id] = missing end
    end
    return want
end

local function AttachmentID(i, a)
    local _, id = GetInboxItem(i, a)
    if Plain(id) and type(id) == "number" then return id end
    local link = GetInboxItemLink and GetInboxItemLink(i, a)
    if Plain(link) and link then
        local instant = C_Item.GetItemInfoInstant(link)
        if type(instant) == "number" then return instant end
    end
    return nil
end

function Mail.Next()
    local want = Wanted()
    if next(want) == nil then return nil end
    for i = 1, GetInboxNumItems() or 0 do
        local _, _, _, _, _, cod, _, hasItem = GetInboxHeaderInfo(i)
        if hasItem and Plain(cod) and (cod or 0) == 0 then
            for a = 1, ATTACHMENTS do
                local id = AttachmentID(i, a)
                if id and want[id] then return i, a, id end
            end
        end
    end
    return nil
end

function Mail.Waiting()
    local n = 0
    for _, c in pairs(Wanted()) do n = n + c end
    return n
end

local function Step()
    if not open or not running then running = false return end
    local i, a, id = Mail.Next()
    local key = i and (i .. ":" .. a .. ":" .. id)
    same = key == last and same + 1 or 0
    last = key
    if not i or not a or not id or taken >= MAX_TAKES or same >= SAME_TRIES then
        running = false
        Changed()
        return
    end
    taken = taken + 1
    inFlight[id] = (inFlight[id] or 0) + 1
    TakeInboxItem(i, a)
    C_Timer.After(STEP, Step)
end

function Mail.Collect()
    if not open or running or not Session.Active() then return false end
    running, taken, last, same = true, 0, nil, 0
    Step()
    return true
end

function Mail.IsOpen() return open end
function Mail.Running() return running end

local events = CreateFrame("Frame")
for _, e in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_FAILED", "BAG_UPDATE_DELAYED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE_DELAYED" then
        inFlight = {}
        Changed()
    elseif event == "MAIL_SHOW" then
        open = true
        Changed()
    elseif event == "MAIL_CLOSED" or event == "MAIL_FAILED" then
        if event == "MAIL_CLOSED" then open = false end
        running = false
        Changed()
    elseif event == "MAIL_INBOX_UPDATE" and Session.Active() and not running then
        C_Timer.After(0.2, Mail.Collect)
    end
end)
