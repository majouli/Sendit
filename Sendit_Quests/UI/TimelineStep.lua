--[[
  TimelineStep: one quest of the chain, right of the timeline's lanes.
  Collapsed (Style.size.step): title + level, then status and place with the
  mini rewards on the right - no description, no reward block.
  Open (the step the player clicked): a raised card with the objective text
  (item names linked), what it requires (all / one of, by name and state),
  what follows, and the reward section (RewardView).
  The quest picked in the list keeps a gold edge in the chain either way.
  Right click: continue the chain (Track.lua via Window:Track).

  Step.Create(parent, onClick) -> step
  Step.Paint(step, id, width, open, root, state) -> height
]]
local _, ns = ...
local T, S, DB, L = Sendit.Theme, ns.Style, ns.Database, ns.L
local Step = {}
ns.TimelineStep = Step
local PAD = S.space.inner

local function Names(ids)
    local out = {}
    for _, id in ipairs(ids) do
        local _, _, _, hex = ns.Style.Hex(ns.Style.Role(ns.Progress.State(id)))
        out[#out + 1] = hex .. DB.Name(id) .. "|r"
    end
    return table.concat(out, ", ")
end

function Step.Create(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.card = T.Fill(b, S.surface.step, "BACKGROUND")
    b.card:SetAllPoints()
    b.cardEdges = T.Border(b, S.surface.hairline)
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.edge = T.Fill(b, "accent", "ARTWORK")
    b.edge:SetPoint("TOPLEFT")
    b.edge:SetPoint("BOTTOMLEFT")
    b.edge:SetWidth(2)
    b.title = T.Text(b, S.font.quest, "text")
    b.title:SetPoint("TOPLEFT", PAD, -7)
    b.title:SetWordWrap(true)
    b.level = T.Text(b, S.font.caption, "textMuted")
    b.level:SetPoint("TOPRIGHT", -PAD, -8)
    b.level:SetJustifyH("RIGHT")
    b.meta = T.Text(b, S.font.meta, "textMuted")
    b.meta:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4)
    b.mini = ns.MiniRewards.Create(b, 20)
    b.mini:SetPoint("TOPRIGHT", -PAD, -24)
    b.body = T.Text(b, S.font.text, "textDim")
    b.body:SetWordWrap(true)
    b.body:SetSpacing(2)
    b.links = T.Text(b, S.font.meta, "textDim")
    b.links:SetWordWrap(true)
    b.links:SetSpacing(3)
    b.rewardHead = T.Text(b, S.font.section, "accent")
    b.rewards = ns.RewardView.Create(b)
    ns.ObjectiveLinks.Attach(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ns.Window:Track(self.questID) else onClick(self.questID) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DB.Name(self.questID), 1, 1, 1)
        GameTooltip:AddLine(L.questID:format(self.questID), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(self.open and L.clickCollapse or L.clickExpand, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.rightTrack, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- "Requires all: A, B" / "Requires one of: ..." / "Next: ..." - known links only.
local function LinkText(id)
    local q, lines = ns.quests[id], {}
    local prev = DB.Prerequisites(id)
    if #prev.all > 0 then lines[#lines + 1] = L.all .. ": " .. Names(prev.all) end
    if #prev.any > 0 then lines[#lines + 1] = L.any .. ": " .. Names(prev.any) end
    local after = DB.Links(id, "after")
    if #after > 0 then lines[#lines + 1] = L.nextQuest .. ": " .. Names(after) end
    if q and q.exclusiveTo and #q.exclusiveTo > 0 then lines[#lines + 1] = L.exclusive .. ": " .. Names(q.exclusiveTo) end
    return table.concat(lines, "\n")
end

function Step.Paint(b, id, width, open, root, state)
    b.questID, b.open = id, open
    b:SetWidth(width)
    local q = ns.quests[id]
    local level = q and q.questLevel and q.questLevel > 0 and q.questLevel
    b.level:SetText(level and L.levelShort:format(level) or "")
    local inner = width - 2 * PAD
    b.title:SetWidth(inner - (level and b.level:GetStringWidth() + 8 or 0))
    b.title:SetMaxLines(open and 0 or 1)
    b.title:SetText(DB.Name(id))
    T.Paint(b.title, open and "accent" or (state == "done" and "textDim" or "text"))
    b.card:SetShown(open)
    for _, e in ipairs(b.cardEdges) do e:SetShown(open) end
    b.edge:SetShown(open or root)
    local data = ns.Rewards.Get(id)
    local miniWidth = math.floor(inner * 0.45)
    local hasMini = not open and ns.MiniRewards.Render(b.mini, miniWidth, data)
    b.mini:SetShown(hasMini and true or false)
    b.meta:SetWidth(inner - (hasMini and b.mini:GetWidth() + 12 or 0))
    local boost = ns.Boost.Get(id)
    local _, _, _, gold = S.Hex("accent")
    b.meta:SetText(S.Label(state) .. "  ·  " .. DB.GroupName(DB.GroupKey(id))
        .. (boost and ("  ·  " .. gold .. S.Upgrade(boost) .. "|r") or ""))
    b.body:SetShown(open)
    b.links:SetShown(open)
    b.rewardHead:SetShown(open)
    b.rewards:SetShown(open)
    if not open then
        b:SetHeight(S.size.step)
        b:Show()
        return S.size.step
    end
    local y = 7 + b.title:GetStringHeight() + 4 + b.meta:GetStringHeight() + S.space.section
    local textWidth = math.min(inner, 620)
    b.body:ClearAllPoints()
    b.body:SetPoint("TOPLEFT", PAD, -y)
    b.body:SetWidth(textWidth)
    b.body:SetText(ns.ObjectiveLinks.Text(id, DB.Description(id)))
    y = y + b.body:GetStringHeight() + S.space.section
    local links = LinkText(id)
    if links ~= "" then
        b.links:ClearAllPoints()
        b.links:SetPoint("TOPLEFT", PAD, -y)
        b.links:SetWidth(textWidth)
        b.links:SetText(links)
        y = y + b.links:GetStringHeight() + S.space.section
    else
        b.links:Hide()
    end
    b.rewardHead:ClearAllPoints()
    b.rewardHead:SetPoint("TOPLEFT", PAD, -y)
    b.rewardHead:SetText(L.rewards)
    y = y + b.rewardHead:GetStringHeight() + 8
    b.rewards:ClearAllPoints()
    b.rewards:SetPoint("TOPLEFT", PAD, -y)
    y = y + ns.RewardView.Render(b.rewards, inner, data) + PAD
    b:SetHeight(y)
    b:Show()
    return y
end
