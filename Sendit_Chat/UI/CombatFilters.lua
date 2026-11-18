--[[
  CombatFilters: the combat log tab's filter strip in Sendit's look - one
  chip per Blizzard quick filter ("My actions", "What happened to me", own
  filters with a quick button), the current one underlined, and a gear for
  Blizzard's combat log menu (settings, filters).

  Why secure buttons: Blizzard's combat log filters may only change through
  Blizzard's own code started by the player's click - ApplyFilterSettings
  calls the protected ClearEventFilters (from addon code:
  ADDON_ACTION_FORBIDDEN, seen in game 0.13.34). A chip is a
  SecureActionButton that presses Blizzard's own quick button (type
  "click"); the gear runs "/click ChatFrame<n>Tab RightButton" (type
  "macro"): Blizzard's tab menu with its chat settings. Sendit never calls
  Blizzard's combat log functions or writes its data; it only reads the
  quick buttons' names and the current filter to draw the chips.

  Combat lockdown: secure buttons cannot be shown, hidden, moved or changed
  in combat, and a protected frame anchored into Sendit's windows would lock
  those too. So the strip is a UIParent child placed by coordinates over the
  combat log tab's top (ChatWindow leaves the room), laid out out of combat;
  in combat it only fades and catches up when combat ends.
  Alpha: Fade owns the strip's alpha (a top-level element; "Chat" in its
  name, so Fade treats it like the chat windows); the combat fade goes on
  the inner content frame, which Fade never touches.
  Blizzard makes quick buttons only for filters that fit its own (hidden)
  bar; the others are in the gear's menu.

  CombatFilters.Tick()   one update pass (driven every 0.2 s; tests call it)
]]
local _, ns = ...
local T, Safe, Mirror = ns.Theme, ns.Safe, ns.Mirror
local L = ns.L

local CombatFilters = {}
ns.CombatFilters = CombatFilters

local HEIGHT = 22
local strip, gear
local chips = {}
local layout, geometry  -- signatures of what is drawn

local function QuickButton(i) return _G["CombatLogQuickButtonFrameButton" .. i] end

-- Blizzard's quick buttons that are in use: { { button, id, name }, ... }
local function Filters()
    local out = {}
    for i = 1, 20 do
        local b = QuickButton(i)
        if not b then break end
        local id = Safe.Num(Safe.Call(b.GetID, b))
        local name = Safe.Str(Safe.Call(b.GetText, b))
        if Safe.Call(b.IsShown, b) == true and id and name then out[#out + 1] = { b, id, name } end
    end
    return out
end

local function CurrentFilter()
    local f, s = _G["Blizzard_CombatLog_Filters"], _G["Blizzard_CombatLog_CurrentSettings"]
    if type(f) ~= "table" then return nil end
    if type(s) == "table" and s.isTemp == true then return nil end
    return Safe.Num(f.currentFilter)
end

local function CombatLogTabName()
    for i = 1, _G["NUM_CHAT_WINDOWS"] or 10 do
        if Mirror.IsCombatLog(i) then return "ChatFrame" .. i .. "Tab" end
    end
    return nil
end

local function Secure(kind)
    local b = CreateFrame("Button", nil, strip.content, "SecureActionButtonTemplate")
    b:SetHeight(HEIGHT)
    b:RegisterForClicks("LeftButtonUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", kind)
    b.hl = T.Tex(b, "BACKGROUND", "ink", 0)
    b.hl:SetAllPoints()
    b:SetScript("OnEnter", function(self)
        T.Color(self.hl, "ink", 0.08)
        if self.tipKey then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L[self.tipKey], 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        T.Color(self.hl, "ink", 0)
        GameTooltip:Hide()
    end)
    return b
end

local function NewChip()
    local b = Secure("click")
    b.text = T.Text(b, 11, "textMuted")
    b.text:SetPoint("CENTER", 0, 1)
    b.line = T.Tex(b, "ARTWORK", "accent", 1)
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 6, 0)
    b.line:SetPoint("BOTTOMRIGHT", -6, 0)
    return b
end

local function Build()
    strip = CreateFrame("Frame", "SenditChatCombatFilters", UIParent)
    strip:SetFrameStrata("LOW")
    strip:SetHeight(HEIGHT)
    strip.bg = T.Tex(strip, "BACKGROUND", "ink", 0.04)
    strip.bg:SetAllPoints()
    local divider = T.Tex(strip, "BORDER", "ink", 0.08)
    divider:SetPoint("BOTTOMLEFT")
    divider:SetPoint("BOTTOMRIGHT")
    divider:SetHeight(1)
    strip.content = CreateFrame("Frame", nil, strip)
    strip.content:SetAllPoints()
    gear = Secure("macro")
    gear:SetWidth(24)
    gear:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
    gear.tipKey = "COMBAT_SETTINGS"  -- read on hover: follows the suite language
    T.Icon(gear, "settings", "textMuted")
    strip:Hide()
end

-- Colours only: allowed in combat too.
local function Paint()
    local current = CurrentFilter()
    for _, c in ipairs(chips) do
        local sel = c.filterId == current
        T.Color(c.text, sel and "text" or "textMuted")
        c.line:SetShown(sel)
    end
end

-- Chips, attributes, widths: out of combat only.
local function Layout(filters)
    local x = 0
    for k, f in ipairs(filters) do
        local c = chips[k] or NewChip()
        chips[k] = c
        c:SetAttribute("clickbutton", f[1])
        c.filterId = f[2]
        c.text:SetText(f[3])
        local w = math.floor((c.text:GetStringWidth() or 40) + 18)
        c:SetWidth(w)
        c:ClearAllPoints()
        c:SetPoint("LEFT", strip, "LEFT", x, 0)
        c:Show()
        x = x + w
    end
    for k = #filters + 1, #chips do chips[k]:Hide() end
    local tab = CombatLogTabName()
    gear:SetAttribute("macrotext", tab and ("/click " .. tab .. " RightButton") or nil)
    gear:SetShown(tab ~= nil)
end

local function Signature(filters)
    local parts = { CombatLogTabName() or "" }
    for _, f in ipairs(filters) do parts[#parts + 1] = f[2] .. "=" .. f[3] end
    return table.concat(parts, "|")
end

local function Place(body)
    local s = body:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local l, t, w = body:GetLeft(), body:GetTop(), body:GetWidth()
    if not (l and t and w) then return end
    local key = ("%d:%d:%d"):format(math.floor(l * s + 0.5), math.floor(t * s + 0.5), math.floor(w * s + 0.5))
    if key == geometry then return end
    geometry = key
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
    strip:SetWidth(w * s)
    strip:SetFrameLevel(body:GetFrameLevel() + 20)
end

function CombatFilters.Tick()
    if not ns.active or not ns.Windows then return end
    local body = ns.Windows.CombatLogBody()
    local combat = InCombatLockdown()
    if not strip then
        if not body or combat then return end
        Build()
    end
    if combat then
        strip.content:SetAlpha(body and 1 or 0)
        if body then Paint() end
        return
    end
    if not body then
        if strip:IsShown() then strip:Hide() end
        return
    end
    local filters = Filters()
    local sig = Signature(filters)
    if sig ~= layout then
        layout = sig
        Layout(filters)
    end
    Place(body)
    Paint()
    strip.content:SetAlpha(1)
    strip:Show()
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + (dt or 0)
    if elapsed < 0.2 then return end
    elapsed = 0
    CombatFilters.Tick()
end)
