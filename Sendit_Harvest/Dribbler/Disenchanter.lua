local _, ns = ...

local D = {}
ns.DribblerDisenchant = D

local Session = ns.DribblerSession
local SPELL = 13262
local BAGS = 4
local WAIT = 15
local BUSY = 5
local WHEEL = { "MOUSEWHEELUP", "MOUSEWHEELDOWN" }
local listeners = {}
local cast
local wheelOwner, clearLater

local function Changed()
    for _, fn in ipairs(listeners) do fn() end
end

function D.OnChange(fn) listeners[#listeners + 1] = fn end
D.SPELL = SPELL

function D.Next()
    for bag = 0, BAGS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and Session.Owns(id) then return bag, slot, id end
        end
    end
    return nil
end

function D.InBags()
    local counts, n = {}, 0
    for bag = 0, BAGS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and Session.Owns(id) then
                counts[id] = (counts[id] or 0) + 1
                local s = Session.Current()
                if counts[id] <= s.owned[id] then n = n + 1 end
            end
        end
    end
    return n
end

local function MatCounts()
    local out = {}
    for _, id in pairs(ns.Mats) do out[id] = C_Item.GetItemCount(id) or 0 end
    return out
end

local function OwnedCounts()
    local out, s = {}, Session.Current()
    for id in pairs(s and s.owned or {}) do out[id] = C_Item.GetItemCount(id) or 0 end
    return out
end

local function Begin(id)
    cast = { id = id, before = MatCounts(), owned = OwnedCounts(), at = GetTime() }
end

local function UsedItem()
    if cast.id then return cast.id end
    for id, n in pairs(cast.owned) do
        if (C_Item.GetItemCount(id) or 0) < n then return id end
    end
    return nil
end

function D.Prepare(button)
    if InCombatLockdown() then return false end
    if cast and not cast.done and GetTime() - cast.at < BUSY then return true end
    local bag, slot, id = D.Next()
    button:SetAttribute("target-bag", bag)
    button:SetAttribute("target-slot", slot)
    button:SetAttribute("type", bag and "spell" or nil)
    if not bag then return false end
    Begin(id)
    return true
end

function D.Settle()
    if not cast or not cast.done then return false end
    local now, gained, any = MatCounts(), {}, false
    for id, n in pairs(now) do
        local d = n - (cast.before[id] or 0)
        if d > 0 then
            gained[id] = d
            any = true
        end
    end
    if not any then
        if GetTime() - cast.at > WAIT then cast = nil end
        return false
    end
    Session.Disenchanted(UsedItem(), gained)
    cast = nil
    Changed()
    return true
end

function D.Create(parent, name)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", SPELL)
    b:SetScript("PreClick", function(self) D.Prepare(self) end)
    b:HookScript("OnEnter", function(self) D.Wheel(self, true) end)
    b:HookScript("OnLeave", function(self) D.Wheel(self, false) end)
    return b
end

function D.Wheel(button, on)
    if InCombatLockdown() then
        clearLater = not on and wheelOwner or nil
        return false
    end
    if wheelOwner then ClearOverrideBindings(wheelOwner) end
    wheelOwner = nil
    if not on then return true end
    for _, key in ipairs(WHEEL) do SetOverrideBindingClick(button, true, key, button:GetName()) end
    wheelOwner = button
    return true
end

function D.WheelActive() return wheelOwner ~= nil end

local events = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                     "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_REGEN_ENABLED" then
        if clearLater then
            clearLater = nil
            D.Wheel(nil, false)
        end
        return
    end
    if event == "BAG_UPDATE_DELAYED" then
        D.Settle()
        Changed()
        return
    end
    if not ns.Plain(unit) or unit ~= "player" or not ns.Plain(spellID) or spellID ~= SPELL then return end
    if event == "UNIT_SPELLCAST_START" then
        if Session.Active() and not (cast and not cast.done and GetTime() - cast.at < BUSY) then Begin(nil) end
        return
    end
    if not cast then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        cast.done, cast.at = true, GetTime()
    else
        cast = nil
    end
end)
