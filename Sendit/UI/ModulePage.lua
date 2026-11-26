--[[
  ModulePage: modules on / off - a switch on every sidebar entry (off modules stay listed, dimmed);
  a switch asks to reload now or later. An off module's entry opens this page (title, notes, switch).
  ModulePage.Switch(button, addonName) / Show(addonName) / Showing(addonName)
]]
local _, ns = ...

local Options, W, L, Suite = ns.Options, ns.Widgets, ns.L, ns.Suite
local function Tx(key) return ns.Locale.Text(L, key) end

local ModulePage = {}
ns.ModulePage = ModulePage

local shown

StaticPopupDialogs["SENDIT_MODULE_RELOAD"] = {
    text = "%s",
    button1 = "",
    button2 = "",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function AskReload(name, on)
    local a = Suite.Get(name)
    local dialog = StaticPopupDialogs.SENDIT_MODULE_RELOAD
    dialog.button1, dialog.button2 = L.RELOAD, L.LATER
    StaticPopup_Show("SENDIT_MODULE_RELOAD", (on and L.MODULE_ON or L.MODULE_OFF):format(a and a.title or name))
end

local function Get(name)
    return function()
        local a = Suite.Get(name)
        return a ~= nil and a.enabled
    end
end

local function Set(name)
    return function(on)
        Suite.SetEnabled(name, on)
        AskReload(name, on)
        Options.Changed()
    end
end

function ModulePage.Switch(button, name)
    if not name then return nil end
    local s = W.Switch(button, Get(name), Set(name), true)
    s:SetPoint("RIGHT", button, "RIGHT", -16, 0)
    s:SetFrameLevel(button:GetFrameLevel() + 2)
    s:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.MODULE_SWITCH_TIP, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return s
end

local page = {
    key = "module",
    core = true,
    hidden = true,
    title = function()
        local a = shown and Suite.Get(shown)
        return a and a.title or ""
    end,
    subtitle = function()
        local a = shown and Suite.Get(shown)
        return a and a.notes or ""
    end,
    build = Options.SettingsPage(function(Lay, c)
        Lay:Section(Tx("MODULE"))
        Lay:Row(Tx("MODULE_ACTIVE"), Tx("MODULE_ACTIVE_DESC"), W.Switch(c,
            function() return shown ~= nil and Get(shown)() end,
            function(on) if shown then Set(shown)(on) end end))
        Lay:EndSection()
        Lay:Note(function()
            local a = shown and Suite.Get(shown)
            if a and a.enabled and not a.loaded then return L.MODULE_AFTER_RELOAD end
            return L.MODULE_IS_OFF
        end)
    end),
}
Options:Register(page)

function ModulePage.Show(name)
    shown = name
    Options:Show("module")
end

function ModulePage.Showing(name)
    local cur = Options:Current()
    return cur == page and shown == name
end
