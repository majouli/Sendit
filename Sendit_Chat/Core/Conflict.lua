--[[
  Conflict: another addon that takes over Blizzard's chat - found by what it does, never by a name list:
  - taint: the client tells which addon replaced a chat function (issecurevariable); hooks
    (hooksecurefunc) leave functions secure, so message filters and our own code never count;
  - parking: an addon that hides a chat frame's text (FontStringContainer alpha 0) draws the chat
    itself; the caller is read from the stack. Sendit Chat never touches that container. It happens
    after login, so the addon is learned (acct.conflicts) and found before the start next time.
  Conflict.Find() -> addon name | nil;  Conflict.Title(name);  Conflict.OnFound(fn(name)) (parking)
]]
local addonName, ns = ...
local Conflict = {}
ns.Conflict = Conflict

local GLOBALS = { "ChatFrame_OnEvent", "ChatFrame_MessageEventHandler", "ChatFrame_OnHyperlinkShow",
    "ChatEdit_SendText", "ChatEdit_ParseText", "ChatEdit_OnEnterPressed", "FCF_OpenNewWindow", "FCF_DockFrame" }
local listeners, parker = {}, nil

local function Loaded(name)
    local api = C_AddOns
    return type(name) == "string" and api and api.IsAddOnLoaded and api.IsAddOnLoaded(name) and true or false
end

local function Other(name)
    return Loaded(name) and name ~= addonName and not name:find("^Sendit") and not name:find("^Blizzard_")
end

-- the addon that tainted it, if a loaded addon other than Sendit
local function Owner(...)
    local ok, secure, by = pcall(issecurevariable, ...)
    if not ok or secure then return nil end
    return Other(by) and by or nil
end

local function Learned()
    local known = ns.acct and ns.acct.conflicts
    for name in pairs(type(known) == "table" and known or {}) do
        if Other(name) then return name end
    end
    return nil
end

function Conflict.Find()
    for i = 1, _G["NUM_CHAT_WINDOWS"] or 10 do
        local cf = _G["ChatFrame" .. i]
        local by = cf and Owner(cf, "AddMessage")
        if by then return by end
    end
    for _, name in ipairs(GLOBALS) do
        local by = _G[name] ~= nil and Owner(name)
        if by then return by end
    end
    return Learned() or (Other(parker) and parker or nil)
end

function Conflict.Title(name)
    local api = C_AddOns
    local title = api and api.GetAddOnMetadata and api.GetAddOnMetadata(name, "Title")
    title = type(title) == "string" and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or ""
    return title ~= "" and title or name
end

function Conflict.OnFound(fn) listeners[#listeners + 1] = fn end

-- the first addon on the stack that is not Sendit or Blizzard's
local function Caller()
    local ok, stack = pcall(debugstack, 3)
    if not ok or type(stack) ~= "string" then return nil end
    for name in stack:gmatch("AddOns[/\\]([^/\\]+)[/\\]") do
        if Other(name) then return name end
    end
    return nil
end

local function Parked(_, alpha)
    if alpha ~= 0 or parker then return end
    local by = Caller()
    if not by then return end
    parker = by
    if ns.acct then
        ns.acct.conflicts = type(ns.acct.conflicts) == "table" and ns.acct.conflicts or {}
        ns.acct.conflicts[by] = true
    end
    for _, fn in ipairs(listeners) do pcall(fn, by) end
end

for i = 1, _G["NUM_CHAT_WINDOWS"] or 10 do
    local cf = _G["ChatFrame" .. i]
    local text = cf and cf.FontStringContainer
    if type(text) == "table" and text.SetAlpha then hooksecurefunc(text, "SetAlpha", Parked) end
end
