--[[
  ErrorLog: the suite's own bug log. While debug mode is on (account design.debug, Errors page) every
  Lua error and blocked protected call of a Sendit addon is kept with stack, locals, count, times,
  session and versions in SenditLogDB. Source: BugGrabber's "BugGrabber.BugGrabbed" when present, else
  our handler first, passing every error on.
  ErrorLog.Enabled() / SetEnabled(on) / List() / Report(entry) / Clear() / OnChange(fn)
  ErrorLog.Record(message, stack, locals)
]]
local _, ns = ...

local ErrorLog = {}
ns.ErrorLog = ErrorLog

local MAX = 50
local STACK_MAX, LOCALS_MAX = 4000, 2000
local NOTICE_GAP = 10

local listeners = {}
local pending = {}  -- errors before the saved variables load
local lastNotice = -math.huge

local function DB()
    if not ns.db then return nil end
    SenditLogDB = SenditLogDB or {}
    SenditLogDB.errors = SenditLogDB.errors or {}
    return SenditLogDB
end

local function Design() return ns.Module and ns:Module("design") end

function ErrorLog.Enabled()
    local m = Design()
    return m ~= nil and m.db ~= nil and m.db.debug == true
end

function ErrorLog.SetEnabled(on)
    local m = Design()
    if m and m.db then m.db.debug = on == true end
end

function ErrorLog.OnChange(fn) listeners[#listeners + 1] = fn end
local function Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

local function Ours(text)
    return type(text) == "string" and (text:find("AddOns[/\\]Sendit") ~= nil or text:find("%[Sendit") ~= nil
        or text:find("Sendit[_%w]*[/\\]") ~= nil)
end

local function Clip(text, max)
    if type(text) ~= "string" then return nil end
    if #text > max then return text:sub(1, max) .. "\n..." end
    return text
end

local function Versions()
    local out = {}
    local api = _G["C_AddOns"]
    local names = { "Sendit" }
    for _, a in ipairs(ns.Suite and ns.Suite.Addons() or {}) do names[#names + 1] = a.name end
    for _, name in ipairs(names) do
        local loaded = api and api.IsAddOnLoaded and api.IsAddOnLoaded(name)
        if loaded then
            local v = api.GetAddOnMetadata and api.GetAddOnMetadata(name, "Version") or "?"
            out[#out + 1] = name:gsub("^Sendit_", "") .. " " .. tostring(v)
        end
    end
    return table.concat(out, ", ")
end

local function Build()
    local fn = _G["GetBuildInfo"]
    if not fn then return "?" end
    local ok, version, build = pcall(fn)
    return ok and (tostring(version) .. "." .. tostring(build)) or "?"
end

local function Notice()
    local now = GetTime()
    if now - lastNotice < NOTICE_GAP then return end
    lastNotice = now
    ns.Print(ns.L.ERROR_NOTICE)
end

local function Store(db, message, stack, locals)
    local list = db.errors
    for i, e in ipairs(list) do
        if e.message == message then
            e.count = (e.count or 1) + 1
            e.last = time()
            if e.session ~= db.session then
                e.session = db.session
                e.stack, e.locals = stack or e.stack, locals or e.locals
            end
            table.remove(list, i)
            table.insert(list, 1, e)
            return e, false
        end
    end
    local e = {
        message = message, stack = stack, locals = locals, count = 1,
        first = time(), last = time(), session = db.session,
        versions = Versions(), build = Build(), locale = GetLocale and GetLocale() or "?",
    }
    table.insert(list, 1, e)
    while #list > MAX do table.remove(list) end
    return e, true
end

function ErrorLog.Record(message, stack, locals)
    if not ErrorLog.Enabled() then return nil end
    message = tostring(message or "?")
    if not (Ours(message) or Ours(stack)) then return nil end
    stack, locals = Clip(stack, STACK_MAX), Clip(locals, LOCALS_MAX)
    local db = DB()
    if not db then
        pending[#pending + 1] = { message, stack, locals }
        return nil
    end
    local e, new = Store(db, message, stack, locals)
    if new then Notice() end
    Changed()
    return e
end

function ErrorLog.List()
    local db = DB()
    return db and db.errors or {}
end

function ErrorLog.Clear()
    local db = DB()
    if db then wipe(db.errors) end
    Changed()
end

local function When(t)
    return t and date("%d.%m. %H:%M:%S", t) or "?"
end

function ErrorLog.Report(e)
    if not e then return "" end
    local lines = {
        ("%dx  %s - %s"):format(e.count or 1, When(e.first), When(e.last)),
        ("Sendit: %s | client %s %s"):format(e.versions or "?", e.build or "?", e.locale or "?"),
        "",
        e.message or "?",
    }
    if e.stack and e.stack ~= "" then lines[#lines + 1] = "\n" .. e.stack end
    if e.locals and e.locals ~= "" then lines[#lines + 1] = "\nLocals:\n" .. e.locals end
    return table.concat(lines, "\n")
end

local function FromBugGrabber(_, id)
    local grabber = _G["BugGrabber"]
    local err = grabber and grabber.GetErrorByID and grabber:GetErrorByID(id)
    if type(err) == "table" then ErrorLog.Record(err.message, err.stack, err.locals) end
end

ErrorLog._FromBugGrabber = FromBugGrabber

local function OwnHandler()
    local previous = geterrorhandler()
    seterrorhandler(function(message, ...)
        if ErrorLog.Enabled() then
            local stack = debugstack and debugstack(3) or nil
            pcall(ErrorLog.Record, message, stack, nil)
        end
        if previous then return previous(message, ...) end
    end)
end

local function Blocked(_, event, addon, func)
    if type(addon) == "string" and addon:find("^Sendit") then
        ErrorLog.Record(("[%s] %s: %s()"):format(event, addon, tostring(func)), "AddOns/" .. addon, nil)
    end
end

local blocked = CreateFrame("Frame")
ns.ownFrames[blocked] = true
blocked:RegisterEvent("ADDON_ACTION_BLOCKED")
blocked:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blocked:SetScript("OnEvent", Blocked)

ns.OnReady(function()
    local db = DB()
    if not db then return end
    db.session = (db.session or 0) + 1
    for _, p in ipairs(pending) do Store(db, p[1], p[2], p[3]) end
    pending = {}
    local registry = _G["EventRegistry"]
    if _G["BugGrabber"] and registry and registry.RegisterCallback then
        registry:RegisterCallback("BugGrabber.BugGrabbed", FromBugGrabber, ErrorLog)
    else
        OwnHandler()
    end
end)
