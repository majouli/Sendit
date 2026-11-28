--[[
  LogRoute: the quest route docked right of the quest log (right of its side tabs) - the chain of the
  quest hovered ("QuestMapLogTitleButton.OnEnter" callback) or picked in the log, that quest ringed
  in gold, each row with its rewards; while a chain is followed, the guide's steps instead. Left click
  opens Sendit Quests (a guide step: the pin), right click the quest menu. Closed until the next pick;
  off in Sendit's Quests page (account: route). Our own named frame, parented to QuestMapFrame.
  LogRoute.Show(questID, hovered) / Refresh() / Hovered(...) / Panel() / Rows()
]]
local _, ns = ...
local T, W, S, DB, L = Sendit.Theme, Sendit.Widgets, ns.Style, ns.Database, ns.L
local Route = {}
ns.LogRoute = Route

local WIDTH, HEADER, TAB_GAP = 320, 50, 48
local TOP, LINE, BOTTOM, MINI = 9, 17, 9, 24  -- row: top pad, name line, meta line, rewards line
local panel, current, closed
local rows = {}

local function Row(i)
    local r = CreateFrame("Button", nil, panel.scroll.content)
    r:SetPoint("RIGHT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.selected = T.Fill(r, "selected", "BACKGROUND")
    r.selected:SetAllPoints()
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    r.node = ns.Icons.Node(r, "bg")
    r.node:SetPoint("TOPLEFT", 12, -TOP)
    r.level = T.Text(r, "small", "textMuted")
    r.level:SetPoint("TOPRIGHT", -12, -TOP - 1)
    r.name = T.Text(r, "label", "text")
    r.name:SetPoint("TOPLEFT", 40, -TOP)
    r.name:SetPoint("RIGHT", r.level, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.meta = T.Text(r, "small", "textMuted")
    r.meta:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.meta:SetPoint("RIGHT", -12, 0)
    r.meta:SetJustifyH("LEFT")
    r.meta:SetWordWrap(false)
    r.mini = ns.MiniRewards.Create(r, 18)
    r.mini:SetPoint("TOPLEFT", r.meta, "BOTTOMLEFT", 0, -5)
    r:SetScript("OnClick", function(self, button)
        if not self.questID then return end
        if button == "RightButton" then ns.Window:Menu(self.questID, self)
        elseif self.step and self.step.place then
            local p, a = self.step.place, self.step.actions[1]
            ns.MapPin.Set(p[1], p[2], p[3], a.quest, a.kind)
            ns.MapPin.Show()
        else ns.Window:OpenQuest(self.questID) end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.questID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DB.Name(self.questID), 1, 0.82, 0, 1, true)
        GameTooltip:AddLine(DB.Description(self.questID), 1, 1, 1, true)
        GameTooltip:AddLine(L.rightTrack, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function Create()
    local log, map = _G["QuestMapFrame"], _G["WorldMapFrame"]
    if panel or not log then return panel ~= nil end
    panel = CreateFrame("Frame", "SenditQuestsRoute", log)
    Sendit.ownFrames[panel] = true
    local dock = map or log
    -- the side tabs stick out right of the map window; their width read safely
    local gap = TAB_GAP
    local tab = log.QuestsTab
    if type(tab) == "table" and tab.GetWidth then
        local ok, w = pcall(tab.GetWidth, tab)
        if ok and type(w) == "number" and not (issecretvalue and issecretvalue(w)) and w > 0 and w < 120 then gap = w + 6 end
    end
    panel:SetWidth(WIDTH)
    panel:SetPoint("TOPLEFT", dock, "TOPRIGHT", gap, 0)
    panel:SetPoint("BOTTOMLEFT", dock, "BOTTOMRIGHT", gap, 0)
    panel:SetFrameStrata("HIGH")
    panel:EnableMouse(true)
    T.Fill(panel, "bg", "BACKGROUND"):SetAllPoints()
    T.Border(panel, "border")
    panel.title = T.Text(panel, "label", "accent")
    panel.title:SetPoint("TOPLEFT", 14, -12)
    panel.title:SetPoint("RIGHT", -40, 0)
    panel.title:SetJustifyH("LEFT")
    panel.title:SetWordWrap(false)
    panel.sub = T.Text(panel, "small", "textMuted")
    panel.sub:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -4)
    panel.close = W.Close(panel, function()
        closed = true
        panel:Hide()
    end)
    panel.close:SetPoint("TOPRIGHT", -8, -8)
    local rule = T.Fill(panel, "divider", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)
    panel.scroll = W.ScrollArea(panel)
    panel.scroll:SetPoint("TOPLEFT", 0, -HEADER - 4)
    panel.scroll:SetPoint("BOTTOMRIGHT", 0, 4)
    panel.empty = T.Text(panel, "body", "textMuted")
    panel.empty:SetPoint("TOPLEFT", 14, -HEADER - 14)
    panel.empty:SetPoint("RIGHT", -14, 0)
    panel.empty:SetJustifyH("LEFT")
    panel.empty:SetWordWrap(true)
    panel:SetScript("OnShow", function() Route.Refresh() end)
    return true
end

local function PaintSteps(steps)
    panel.title:SetText(L.guideTitle)
    panel.empty:SetText(L.trackDone)
    panel.empty:SetShown(#steps == 0)
    local y = 0
    for i, step in ipairs(steps) do
        local r = rows[i] or Row(i)
        local a = step.actions[1]
        r.questID, r.step = a.quest, step
        r.node:Set(i == 1 and "next" or "open", i == 1)
        r.selected:SetShown(i == 1)
        r.name:SetText(step.title)
        T.Paint(r.name, i == 1 and "accent" or "text")
        r.level:SetText(tostring(i))
        r.meta:SetText(step.place and DB.GroupName(DB.GroupKey(a.quest)) or L.guideNoPlace)
        r.mini:Hide()
        local height = TOP + 2 * LINE + BOTTOM
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("RIGHT")
        r.top = y
        r:SetHeight(height)
        r:Show()
        y = y + height
    end
    for i = #steps + 1, #rows do rows[i]:Hide() end
    panel.sub:SetText(ns.Guide.UsesSPF() and "Shortest Path Forever" or L.menuChain)
    panel.scroll.content:SetSize(WIDTH, math.max(1, y))
    pcall(panel.scroll.SetVerticalScroll, panel.scroll, 0)
end

local function Paint()
    if not panel or not panel:IsVisible() then return end  -- shown inside a closed map; OnShow paints
    local followed = ns.Guide.Following()
    if followed then return PaintSteps(ns.Guide.Steps(followed)) end
    local id = current or ns.Progress.Selected()
    local chain = id and DB.Chain(id) or {}
    panel.title:SetText(L.routeTitle)
    panel.empty:SetText(L.routeEmpty)
    panel.empty:SetShown(#chain == 0)
    local at, y, atY = 0, 0, 0
    for i, step in ipairs(chain) do
        local r = rows[i] or Row(i)
        local state = S.Show(step.id, DB.Prerequisites(step.id))
        local q = ns.quests[step.id]
        r.questID, r.step = step.id, nil
        r.node:Set(state, step.id == id)
        r.selected:SetShown(step.id == id)
        r.name:SetText(DB.Name(step.id))
        T.Paint(r.name, step.id == id and "accent" or (state == "done" and "textDim" or "text"))
        r.level:SetText(q and q.questLevel and L.levelShort:format(q.questLevel) or "")
        r.meta:SetText(S.Label(state) .. "  ·  " .. DB.GroupName(DB.GroupKey(step.id)))
        local mini = ns.MiniRewards.Render(r.mini, WIDTH - 70, ns.Rewards.Get(step.id)) and true or false
        r.mini:SetShown(mini)
        local height = TOP + 2 * LINE + (mini and MINI or 0) + BOTTOM
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r.top = y
        r:SetPoint("RIGHT")
        r:SetHeight(height)
        r:Show()
        if step.id == id then at, atY = i, y + height / 2 end
        y = y + height
    end
    for i = #chain + 1, #rows do rows[i]:Hide() end
    panel.sub:SetText(#chain > 0 and L.chainLine:format(at, #chain) or "")
    panel.scroll.content:SetSize(WIDTH, math.max(1, y))
    if at > 0 then
        local view = panel.scroll:GetHeight() or 0
        local target = math.max(0, atY - view / 2)
        local max = math.max(0, y - view)
        pcall(panel.scroll.SetVerticalScroll, panel.scroll, math.min(target, max))
    end
end

local function Enabled() return not ns.disabled and (ns.module.db == nil or ns.module.db.route ~= false) end

function Route.Show(id, hovered)
    if not Enabled() then
        if panel then panel:Hide() end
        return
    end
    if type(id) == "number" and id > 0 then
        current = id
        -- a closed route comes back with a pick, not a hover
        if not hovered then closed = false end
    end
    if not Create() then return end
    panel:SetShown(not closed)
    Paint()
end

function Route.Refresh() Paint() end
function Route.Panel() return panel end
function Route.Rows() return rows end

local function Hovered(_, _, questID)
    if issecretvalue and issecretvalue(questID) then return end
    if type(questID) == "number" and questID > 0 and questID ~= current then Route.Show(questID, true) end
end
Route.Hovered = Hovered
local registry = _G["EventRegistry"]
if registry and registry.RegisterCallback then
    pcall(registry.RegisterCallback, registry, "QuestMapLogTitleButton.OnEnter", Hovered, Route)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        if Enabled() and Create() and not closed then panel:Show() end
    end
    Paint()
end)
Sendit.OnSettingsChanged(function()
    if panel and not Enabled() then panel:Hide() elseif panel and not closed and _G["QuestMapFrame"] then
        panel:Show()
    end
end)
