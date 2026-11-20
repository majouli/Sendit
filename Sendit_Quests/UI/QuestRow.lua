--[[
  QuestRow: one list entry (fixed height, virtual list) - node, title, level; place, status (and
  "from level X" for preview quests); its rewards or an objective preview; the chain line, and while
  the boost runs its best upgrade at the bottom right. Right click: the quest menu.
  QuestRow.Create(parent, onClick) -> row;  QuestRow.Paint(row, id, width, selected)
]]
local _, ns = ...
local T, S, DB, L = Sendit.Theme, ns.Style, ns.Database, ns.L
local Row = {}
ns.QuestRow = Row

function Row.Create(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(S.size.row)
    b.selection = T.Fill(b, S.surface.rowSelected, "BACKGROUND", 1)
    b.selection:SetAllPoints()
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    b.edge = T.Fill(b, "accent", "ARTWORK")
    b.edge:SetPoint("TOPLEFT")
    b.edge:SetPoint("BOTTOMLEFT")
    b.edge:SetWidth(2)
    local line = T.Fill(b, S.surface.hairline, "BORDER")
    line:SetPoint("BOTTOMLEFT", 12, 0)
    line:SetPoint("BOTTOMRIGHT", -12, 0)
    line:SetHeight(1)
    b.node = ns.Icons.Node(b, S.surface.list)
    b.node:SetPoint("TOPLEFT", 12, -11)
    b.title = T.Text(b, S.font.quest, "text")
    b.title:SetPoint("TOPLEFT", 36, -11)
    b.level = T.Text(b, S.font.caption, "textMuted")
    b.level:SetPoint("TOPRIGHT", -12, -12)
    b.level:SetJustifyH("RIGHT")
    b.meta = T.Text(b, S.font.meta, "textMuted")
    b.meta:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4)
    b.rewards = ns.MiniRewards.Create(b, S.size.icon)
    b.rewards:SetPoint("TOPLEFT", b.meta, "BOTTOMLEFT", 0, -7)
    b.preview = T.Text(b, S.font.meta, "textDim")
    b.preview:SetPoint("TOPLEFT", b.meta, "BOTTOMLEFT", 0, -12)
    b.glow = T.Fill(b, "accent", "BACKGROUND", 2, 0.10)
    b.glow:SetAllPoints()
    b.boost = CreateFrame("Frame", nil, b)
    b.boost:SetSize(1, 20)
    b.boost:SetPoint("BOTTOMRIGHT", -12, 5)
    b.boost:EnableMouse(true)
    b.boost.icon = ns.RewardIcon.Create(b.boost, 20)
    b.boost.icon:SetPoint("RIGHT")
    b.boost.text = T.Text(b.boost, S.font.meta, "accent")
    b.boost.text:SetPoint("RIGHT", b.boost.icon, "LEFT", -6, 0)
    b.boost.text:SetJustifyH("RIGHT")
    b.boost:SetScript("OnEnter", function(self)
        if not self.result then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S.Upgrade(self.result), 1, 0.82, 0)
        GameTooltip:AddLine(S.UpgradeDetail(self.result), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b.boost:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.chain = T.Text(b, S.font.caption, "textMuted")
    b.chain:SetPoint("BOTTOMLEFT", 36, 10)
    b.chainRewards = ns.MiniRewards.Create(b, 16)
    b.chainRewards:SetPoint("LEFT", b.chain, "RIGHT", 8, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ns.Window:Menu(self.questID, self) else onClick(self.questID) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DB.Name(self.questID), 1, 1, 1)
        GameTooltip:AddLine(L.questID:format(self.questID), 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L.rightTrack, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- "Chain 2 of 5" and what the whole chain gives; "" and nil without links
function Row.ChainLine(id)
    local rows = DB.Chain(id)
    if #rows <= 1 then return "", nil end
    return L.chainLine:format(ns.Progress.Summary(rows).done, #rows), ns.Rewards.Chain(rows)
end

function Row.Paint(b, id, width, selected)
    b.questID = id
    b:SetWidth(width)
    local q = ns.quests[id]
    local state = S.Show(id, DB.Prerequisites(id))
    b.node:Set(state, false)
    local level = q and q.questLevel and q.questLevel > 0 and q.questLevel
    b.level:SetText(level and L.levelShort:format(level) or "")
    b.title:SetWidth(width - 48 - (level and b.level:GetStringWidth() + 8 or 0))
    b.title:SetText(DB.Name(id))
    T.Paint(b.title, selected and "accent" or "text")
    b.selection:SetShown(selected)
    b.edge:SetShown(selected)
    local boost = ns.Boost.Get(id)
    b.glow:SetShown(boost ~= nil)
    b.boost:SetShown(boost ~= nil)
    b.boost.result = boost
    local boostWidth = 0
    if boost then
        b.boost.icon:Set(boost.itemID, 1, false)
        b.boost.text:SetText(S.Upgrade(boost))
        boostWidth = b.boost.text:GetStringWidth() + 32
        b.boost:SetWidth(boostWidth)
    end
    b.meta:SetWidth(width - 48)
    local need = ns.Boost.NeedsLevel(q)  -- a preview quest: not takeable yet
    local _, _, _, warn = S.Hex("danger")
    b.meta:SetText(DB.GroupName(DB.GroupKey(id)) .. "  ·  " .. ns.Style.Label(state)
        .. (need and ("  ·  " .. warn .. L.needsLevel:format(need) .. "|r") or ""))
    local has = ns.MiniRewards.Render(b.rewards, width - 48, ns.Rewards.Get(id))
    b.preview:SetShown(not has)
    if not has then
        b.preview:SetWidth(width - 48)
        b.preview:SetText((DB.Description(id):gsub("[\r\n]+", " ")))
    end
    local label, chainData = Row.ChainLine(id)
    b.chain:SetText(label)
    b.chain:SetWidth(b.chain:GetStringWidth() + 2)
    local room = width - 56 - b.chain:GetWidth() - (boost and boostWidth + 12 or 0)
    b.chainRewards:SetShown(chainData ~= nil and room > 40)
    if chainData and room > 40 then ns.MiniRewards.Render(b.chainRewards, room, chainData) end
    b:Show()
end
