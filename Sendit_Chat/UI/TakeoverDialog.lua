--[[
  TakeoverDialog: another addon has the chat (Conflict.Find). Take over = switch that addon off and
  reload; keep it = Sendit Chat stays off for this addon until /chat on (acct.keepOther) - if both
  already run, the game reloads too.
  TakeoverDialog.Show(addon)
]]
local _, ns = ...
local T, Widgets = ns.Theme, ns.Widgets
local L = ns.L

local Dialog = {}
ns.TakeoverDialog = Dialog

local WIDTH = 420
local box, other

local function TakeOver()
    local api = C_AddOns
    if api and api.DisableAddOn then
        api.DisableAddOn(other)
        if api.SaveAddOns then api.SaveAddOns() end
    end
    if ns.acct then ns.acct.keepOther = nil end
    ReloadUI()
end

local function Keep()
    if ns.acct then ns.acct.keepOther = other end
    if ns.active then ReloadUI() return end
    box:Hide()
    ns.Print(L.YIELD:format(ns.Conflict.Title(other)))
end

local function Build()
    box = T.Panel(UIParent, "DIALOG", "SenditTakeoverDialog")
    box:SetWidth(WIDTH)
    box:SetPoint("CENTER", 0, 120)
    box:SetClampedToScreen(true)
    T.Decorate(box, "panel")
    box.title = T.Text(box, 14, "text")
    box.title:SetPoint("TOPLEFT", 18, -16)
    box.body = T.Text(box, 11, "textMuted")
    box.body:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -10)
    box.body:SetWidth(WIDTH - 36)
    box.body:SetJustifyH("LEFT")
    box.yes = Widgets.Button(box, "", TakeOver)
    box.yes:SetSize((WIDTH - 46) / 2, 28)
    box.yes:SetPoint("BOTTOMLEFT", 18, 16)
    T.Color(box.yes.bg, "accent", 0.35)
    box.yes:SetScript("OnLeave", function(self) T.Color(self.bg, "accent", 0.35) end)
    box.yes:SetScript("OnEnter", function(self) T.Color(self.bg, "accent", 0.5) end)
    box.no = Widgets.Button(box, "", Keep)
    box.no:SetSize((WIDTH - 46) / 2, 28)
    box.no:SetPoint("BOTTOMRIGHT", -18, 16)
end

function Dialog.Show(addon)
    other = addon
    if not box then Build() end
    local name = ns.Conflict.Title(addon)
    box.title:SetText(L.TAKEOVER_TITLE)
    box.body:SetText(L.TAKEOVER_TEXT:format(name, name))
    box.yes.text:SetText(L.TAKEOVER_YES)
    box.no.text:SetText(L.TAKEOVER_NO:format(name))
    box:SetHeight(16 + box.title:GetStringHeight() + 10 + box.body:GetStringHeight() + 22 + 28 + 16)
    box:Show()
end
