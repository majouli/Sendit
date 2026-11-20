--[[
  LootCards: a card glides in above the chat - for every loot roll (won gold, lost grey) and own loot of
  lootCardQuality or better (glowing quality frame, epic+ breathes). Up to MAX stack, HOLD s each;
  tooltip, shift / ctrl click as Blizzard's, right click dismisses. Fed by CHAT_MSG_LOOT (not the
  mirrored lines); secret lines skipped. Its own top-level frame, hidden while empty (Fade shows it).
]]
local _, ns = ...
local T, Loot = ns.Theme, ns.Loot

local LootCards = {}
ns.LootCards = LootCards

local MAX = 4
local HOLD = 6
local W, H, ICON, GAP = 270, 50, 38, 6

local stack, cards = nil, {}

local function Layout()
    if not stack then return end
    local n = 0
    for _, c in ipairs(cards) do
        if c.live then
            c:ClearAllPoints()
            c:SetPoint("BOTTOMLEFT", stack, "BOTTOMLEFT", 0, n * (H + GAP))
            n = n + 1
        end
    end
    stack:SetShown(n > 0)
end

local function Remove(card)
    card.live = false
    card:Hide()
    Layout()
end

local function FadeOut(card, token)
    if card.token ~= token or not card.live then return end
    if card:IsMouseOver() then
        C_Timer.After(1, function() FadeOut(card, token) end)
        return
    end
    card.outAnim:Play()
    C_Timer.After(0.5, function() if card.token == token then Remove(card) end end)
end

local function Border(parent, size)
    local b = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = T.Tex(parent, "OVERLAY", "ink", 1)
        T.Own(t)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT", 0, 0); t:SetPoint(side .. "RIGHT", 0, 0); t:SetHeight(size)
        else
            t:SetPoint("TOP" .. side, 0, 0); t:SetPoint("BOTTOM" .. side, 0, 0); t:SetWidth(size)
        end
        b[#b + 1] = t
    end
    return b
end

local function NewCard()
    local c = CreateFrame("Button", nil, stack)
    c:SetSize(W, H)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.bg = T.Tex(c, "BACKGROUND", "bg", 0.94)
    c.bg:SetAllPoints()
    c.wash = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.wash:SetTexture(T.WHITE)
    c.wash:SetAllPoints()
    c.wash:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.16), CreateColor(1, 1, 1, 0))
    c.bar = T.Tex(c, "ARTWORK", "accent", 1)
    T.Own(c.bar)
    c.bar:SetPoint("TOPLEFT"); c.bar:SetPoint("BOTTOMLEFT"); c.bar:SetWidth(3)

    local holder = CreateFrame("Frame", nil, c)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("LEFT", 10, 0)
    c.glow = holder:CreateTexture(nil, "BACKGROUND")
    c.glow:SetTexture(T.WHITE)
    c.glow:SetPoint("TOPLEFT", -4, 4)
    c.glow:SetPoint("BOTTOMRIGHT", 4, -4)
    c.icon = holder:CreateTexture(nil, "ARTWORK")
    c.icon:SetAllPoints()
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.frame = Border(holder, 1)

    c.name = T.Text(c, 13, "text")
    T.Own(c.name)
    c.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -3)
    c.name:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    c.name:SetWordWrap(false)
    c.sub = T.Text(c, 10, "textMuted")
    c.sub:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", 10, 3)
    c.sub:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    c.sub:SetWordWrap(false)

    c.inAnim = c:CreateAnimationGroup()
    local slide = c.inAnim:CreateAnimation("Translation")
    slide:SetOffset(-24, 0)
    slide:SetDuration(0)
    slide:SetOrder(1)
    local back = c.inAnim:CreateAnimation("Translation")
    back:SetOffset(24, 0)
    back:SetDuration(0.35)
    back:SetSmoothing("OUT")
    back:SetOrder(2)
    local appear = c.inAnim:CreateAnimation("Alpha")
    appear:SetFromAlpha(0)
    appear:SetToAlpha(1)
    appear:SetDuration(0.35)
    appear:SetOrder(2)

    c.outAnim = c:CreateAnimationGroup()
    local vanish = c.outAnim:CreateAnimation("Alpha")
    vanish:SetFromAlpha(1)
    vanish:SetToAlpha(0)
    vanish:SetDuration(0.5)
    c.outAnim:SetToFinalAlpha(true)

    c.pulse = c.glow:CreateAnimationGroup()
    c.pulse:SetLooping("BOUNCE")
    local breathe = c.pulse:CreateAnimation("Alpha")
    breathe:SetFromAlpha(0.35)
    breathe:SetToAlpha(1)
    breathe:SetDuration(0.9)
    breathe:SetSmoothing("IN_OUT")

    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        if pcall(GameTooltip.SetHyperlink, GameTooltip, self.link) then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            self.token = nil
            Remove(self)
            return
        end
        local handle = _G["HandleModifiedItemClick"]
        if handle then pcall(handle, self.link) end
    end)
    return c
end

local function Acquire()
    for _, c in ipairs(cards) do
        if not c.live then return c end
    end
    if #cards < MAX then
        local c = NewCard()
        cards[#cards + 1] = c
        return c
    end
    -- full: the oldest card makes room
    local oldest = cards[1]
    for _, c in ipairs(cards) do
        if c.born < oldest.born then oldest = c end
    end
    return oldest
end

-- opts: { state = "won" | "lost", note } for rolls
function LootCards.Show(link, count, opts)
    if not stack then return nil end
    local item = Loot.Item(link)
    local c = Acquire()
    -- newest at the bottom
    for i, x in ipairs(cards) do if x == c then table.remove(cards, i) break end end
    table.insert(cards, 1, c)
    c.link = link
    c.born = GetTime()
    c.live = true
    local state = opts and opts.state
    local r, g, b = item.r, item.g, item.b
    -- quality; gold for a won roll, grey for a lost one
    local fr, fg, fb = r, g, b
    if state == "won" then fr, fg, fb = 1, 0.82, 0.2 elseif state == "lost" then fr, fg, fb = 0.45, 0.47, 0.52 end
    c.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    c.icon:SetDesaturated(state == "lost")
    c.glow:SetVertexColor(fr, fg, fb, state == "lost" and 0.15 or 0.45)
    for _, t in ipairs(c.frame) do t:SetVertexColor(fr, fg, fb, 1) end
    c.bar:SetVertexColor(fr, fg, fb, 1)
    c.wash:SetGradient("HORIZONTAL", CreateColor(fr, fg, fb, 0.18), CreateColor(fr, fg, fb, 0))
    c.name:SetText(link:match("|h%[?(.-)%]?|h") or link)
    if state == "lost" then c.name:SetTextColor(r * 0.6, g * 0.6, b * 0.6, 1) else c.name:SetTextColor(r, g, b, 1) end
    local parts = {}
    if state == "won" then parts[#parts + 1] = "|cffffd100" .. ns.L.WON .. "|r" end
    if state == "lost" then parts[#parts + 1] = "|cffff6464" .. (opts.note or ns.L.LOST) .. "|r" end
    if state == "won" and opts.note then parts[#parts + 1] = opts.note end
    if count and count > 1 then parts[#parts + 1] = "×" .. count end
    if item.detail and state ~= "lost" then parts[#parts + 1] = item.detail end
    c.sub:SetText(table.concat(parts, "   "))
    if state == "won" or (item.quality >= 4 and state ~= "lost") then c.pulse:Play() else c.pulse:Stop() end
    c.outAnim:Stop()
    c:SetAlpha(1)
    c:Show()
    Layout()
    c.inAnim:Play()
    local token = {}
    c.token = token
    C_Timer.After(HOLD, function() FadeOut(c, token) end)
    return c
end

-- on top of the whisper toasts, moving with them
function LootCards.Anchor()
    local main = ns.Windows.Main()
    if not stack or not main then return end
    stack:ClearAllPoints()
    local toasts = ns.WhisperToasts and ns.WhisperToasts.Frame()
    if toasts then
        stack:SetPoint("BOTTOMLEFT", toasts, "TOPLEFT", 0, 0)
    else
        stack:SetPoint("BOTTOMLEFT", main.frame, "TOPLEFT", 0, 8)
    end
end

local function OnLoot(_, text)
    if not ns.db.lootCards then return end
    local info = Loot.Parse(text)
    if not info or not info.link or not info.link:find("|Hitem:", 1, true) then return end
    if Loot.Item(info.link).quality < ns.db.lootCardQuality then return end
    if ns.Rolls and ns.Rolls.RecentlyWon(info.link) then return end  -- the "won" card showed it
    LootCards.Show(info.link, info.count)
end
LootCards._OnLoot = OnLoot

ns.OnReady(function()
    stack = CreateFrame("Frame", "SenditLootCards", UIParent)
    stack:SetSize(W, H)
    stack:SetFrameStrata("MEDIUM")
    stack:Hide()
    LootCards.Anchor()
    ns.Listen("CHAT_MSG_LOOT", OnLoot)
end)
