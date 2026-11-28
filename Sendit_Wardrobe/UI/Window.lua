--[[
  Window: the wardrobe - left the list of the tab (sets, highlights, looks, outfits) with search and
  filter chips, in the middle the character wearing the outfit, right the outfit's pieces with their
  sources and the outfit controls (name + save, my gear, undress, delete).
  A set replaces the outfit, a look goes into its slot, a saved outfit loads.
  Window.Open() / Hide() / Toggle() / Shown() / Refresh() / Search(text) / Probe() -> lines. Size: ns.module.db.
]]
local _, ns = ...
local L, Browse, Outfit, Rows, Catalog = ns.L, ns.Browse, ns.Outfit, ns.Rows, ns.Catalog
local T, W = Sendit.Theme, Sendit.Widgets
local Window = {}
ns.Window = Window
local PAD, HEADER, LEFT, RIGHT, FOOT = 16, 62, 420, 350, 78
local MIN_W, MIN_H = 1060, 640
local frame
local query = ""

local function Db() return ns.module.db end

-- collected / all looks: counted once, again after the collection changed
local stats
local function Stats()
    if not stats then
        local have = 0
        for _, look in ipairs(Catalog.Looks()) do
            if ns.Collection.Look(look) then have = have + 1 end
        end
        stats = { have, #Catalog.Looks() }
    end
    return stats[1], stats[2]
end

local function RefreshList(keep)
    if not frame then return end
    local entries, count = Browse.List(query)
    frame.list:SetEntries(entries, keep)
    frame.count:SetText(L.results:format(count))
    frame.empty:SetShown(count == 0)
    frame.empty:SetText(Browse.Get("tab") == "outfits" and L.noOutfits or L.nothing)
end

function Window.Refresh(keep)
    if not frame or not frame:IsShown() then return end
    local tab = Browse.Get("tab") or "sets"
    frame.tabs:Refresh()
    frame.filters:Refresh(tab)
    frame.search.hint:SetText(L.searchHint)
    frame.title:SetText(L.title)
    local have, total = Stats()
    frame.sub:SetText(L.subtitle:format(have, total))
    RefreshList(keep)
    frame.pieces:Refresh()
    frame.delete:SetShown(Outfit.Name() ~= nil)
    frame.saveLabel:SetText(L.saveAs)
end

function Window.Search(text)
    if not frame then return end
    frame.search:SetText(text or "")
end

local function Pick(e, button)
    if not e then return end
    if e.type == "set" then
        Outfit.FromSet(e.set)
        Rows.picked = e.set
    elseif e.type == "look" then
        local id = Browse.Best(e.look)
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local _, link = ns.Read(C_Item.GetItemInfo, id)
            local insert = _G["ChatEdit_InsertLink"]
            if link and insert then insert(link) end
            return
        end
        local it = Catalog.Item(id)
        if button == "RightButton" and it then Outfit.Clear(it.slot) else Outfit.Put(id) end
    elseif e.type == "outfit" then
        if button == "RightButton" then
            W.ShowMenu(GetMouseFoci and GetMouseFoci()[1] or frame, { { "load", L.load }, { "delete", L.delete } },
                nil, function(v)
                    if v == "load" then
                        Outfit.Load(e.index)
                        frame.name:SetText(e.outfit.name)
                    else
                        Outfit.Delete(e.index)
                        Window.Refresh(true)  -- the rows after it hold new indexes
                    end
                end)
            return
        end
        Outfit.Load(e.index)
        frame.name:SetText(e.outfit.name)
    end
end

local function Header()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", PAD, -15)
    icon:SetTexture(ns.ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.title = T.Text(frame, "title", "text")
    frame.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    frame.sub = T.Text(frame, "small", "textMuted")
    frame.sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)
    W.Close(frame, Window.Hide):SetPoint("TOPRIGHT", -10, -12)
    local rule = T.Fill(frame, "divider", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)
end

local function LeftColumn()
    local col = CreateFrame("Frame", nil, frame)
    col:SetPoint("TOPLEFT", PAD, -(HEADER + 12))
    col:SetPoint("BOTTOMLEFT", PAD, PAD)
    col:SetWidth(LEFT)
    frame.tabs = W.Segmented(col, {
        { "sets", function() return L.tabSets end }, { "highlights", function() return L.tabHighlights end },
        { "looks", function() return L.tabLooks end }, { "outfits", function() return L.tabOutfits end },
    }, function() return Browse.Get("tab") or "sets" end, function(v)
        Browse.Set("tab", v)
        Window.Refresh()
    end)
    frame.tabs:SetPoint("TOPLEFT")
    frame.search = W.Search(col, L.searchHint, function(text)
        query = text
        if frame:IsShown() then RefreshList() end
    end)
    frame.search:SetPoint("TOPLEFT", 0, -38)
    frame.search:SetPoint("RIGHT")
    frame.filters = ns.Filters.Create(col, function() Window.Refresh() end)
    frame.filters:SetPoint("TOPLEFT", 0, -74)
    frame.filters:SetPoint("RIGHT")
    frame.count = T.Text(col, "caption", "textMuted")
    frame.count:SetPoint("TOPRIGHT", 0, -112)
    frame.list = ns.List.Create(col, Rows.KINDS)
    frame.list:SetPoint("TOPLEFT", 0, -128)
    frame.list:SetPoint("BOTTOMRIGHT")
    frame.empty = T.Text(col, "body", "textMuted")
    frame.empty:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 4, -10)
    frame.empty:SetPoint("RIGHT", -4, 0)
    frame.empty:SetWordWrap(true)
end

local function Footer(col)
    local foot = CreateFrame("Frame", nil, col)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(FOOT)
    local rule = T.Fill(foot, "divider", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT")
    rule:SetPoint("TOPRIGHT")
    frame.saveLabel = T.Text(foot, "caption", "textMuted")
    frame.saveLabel:SetPoint("TOPLEFT", 0, -10)
    local save = W.Button(foot, L.save, function()
        if not Outfit.Save(frame.name:GetText()) then frame.name:SetFocus() return end
        frame.name:ClearFocus()
        Window.Refresh(true)
    end, "primary")
    save:SetPoint("TOPRIGHT", 0, -24)
    frame.name = W.Search(foot, L.namePlaceholder, function() end)
    frame.name:SetPoint("TOPLEFT", 0, -24)
    frame.name:SetPoint("RIGHT", save, "LEFT", -8, 0)
    frame.name:SetScript("OnEnterPressed", function() save:Click() end)
    local gear = W.Button(foot, L.myGear, function() Outfit.FromEquipped() end)
    gear:SetPoint("BOTTOMLEFT", 0, 0)
    local undress = W.Button(foot, L.undress, function() Outfit.Empty() frame.name:SetText("") end)
    undress:SetPoint("LEFT", gear, "RIGHT", 6, 0)
    frame.delete = W.Button(foot, L.delete, function()
        for i, o in ipairs(Outfit.Saved()) do
            if o.name == Outfit.Name() then Outfit.Delete(i) break end
        end
        frame.name:SetText("")
        Window.Refresh(true)
    end)
    frame.delete:SetPoint("BOTTOMRIGHT", 0, 0)
end

local function RightColumn()
    local col = CreateFrame("Frame", nil, frame)
    col:SetPoint("TOPRIGHT", -PAD, -(HEADER + 12))
    col:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    col:SetWidth(RIGHT)
    frame.pieces = ns.Pieces.Create(col)
    frame.pieces:SetPoint("TOPLEFT")
    frame.pieces:SetPoint("BOTTOMRIGHT", 0, FOOT + 8)
    Footer(col)
end

local function Stage()
    frame.stage = ns.Model.Create(frame)
    frame.stage:SetPoint("TOPLEFT", PAD + LEFT + PAD, -(HEADER + 1))
    frame.stage:SetPoint("BOTTOMRIGHT", -(PAD + RIGHT + PAD), 1)
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local edge = T.Fill(frame, "divider", "ARTWORK")
        edge:SetWidth(1)
        edge:SetPoint("TOP" .. side, frame.stage, "TOP" .. side, 0, 0)
        edge:SetPoint("BOTTOM" .. side, frame.stage, "BOTTOM" .. side, 0, 0)
    end
end

local function Create()
    local db = Db()
    frame = CreateFrame("Frame", "SenditWardrobeFrame", UIParent)
    Sendit.ownFrames[frame] = true
    Sendit.Widgets.Stacked(frame)
    frame:SetSize(math.max(MIN_W, db.width or 0), math.max(MIN_H, db.height or 0))
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H) end
    T.Fill(frame, "bg", "BACKGROUND"):SetAllPoints()
    local borders = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, edge in ipairs(borders) do edge:SetShown(not on) end
    end })
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -40, 0)
    drag:SetHeight(HEADER)
    W.Movable(frame, drag, { store = db, key = "point", default = { "CENTER", "CENTER", 0, 0 } })
    W.Grip(frame, function(w, h) db.width, db.height = math.floor(w), math.floor(h) end)
    Header()
    LeftColumn()
    RightColumn()
    Stage()
    tinsert(UISpecialFrames, "SenditWardrobeFrame")
    frame:SetScript("OnShow", function()
        frame.stage:Dress(Outfit.Items())
        frame.stage:Load()
        Window.Refresh(true)
        ns.Learn.Run()
    end)
    frame:SetScript("OnSizeChanged", function() if frame:IsShown() then frame.pieces:Refresh() end end)
    Rows.onPick = Pick
    if not next(Outfit.Items()) then Outfit.FromEquipped() end
    frame:Hide()  -- a new frame is shown: hidden first, Open's Show runs OnShow (model, list)
end

function Window.Open()
    if not frame then Create() end
    frame:Show()
    T.FadeIn(frame, 0.15, 6)
end

-- diagnostics: how each piece of the outfit went onto the model (English, chat)
function Window.Probe()
    local out = {}
    local m = frame and frame.stage.model
    out[#out + 1] = ("model: %s, shown %s, helm shown %s"):format(m and m:GetObjectType() or "none",
        tostring(frame and frame:IsShown()), tostring(ns.Read(_G["ShowingHelm"])))
    for _, slot in ipairs(ns.Slots.ORDER) do
        local id = Outfit.Get(slot)
        if id then
            local t = frame and frame.stage.tries[slot]
            local name = ns.Read(C_Item.GetItemInfo, id)
            out[#out + 1] = ("%s %d %s: icon %s, loaded %s, try-on %s"):format(slot, id, Catalog.ItemName(id),
                tostring(ns.Read(C_Item.GetItemIconByID, id)), tostring(name ~= nil),
                t and (t[2] .. " -> " .. tostring(t[3])) or "not tried")
        end
    end
    return out
end

function Window.Hide() if frame then frame:Hide() end end
function Window.Toggle() if frame and frame:IsShown() then Window.Hide() else Window.Open() end end
function Window.Shown() return frame ~= nil and frame:IsShown() end

local function Dressed()
    Rows.picked = nil
    if not frame then return end
    frame.stage:Dress(Outfit.Items())
    if frame:IsShown() then
        frame.list:Repaint()
        frame.pieces:Refresh()
        frame.delete:SetShown(Outfit.Name() ~= nil)
    end
end
Outfit.OnChange(Dressed)

local pending = false
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        Window.Refresh(true)
    end)
end
ns.Collection.OnChange(function()
    stats = nil
    Soon()
end)
ns.Learn.OnChange(function()
    stats = nil
    Soon()
end)
Sendit.OnSettingsChanged(Soon)
-- names and icons arriving: repaint what is in view, no new list
local repaint = false
local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function()
    if repaint or not (frame and frame:IsShown()) then return end
    repaint = true
    C_Timer.After(0.3, function()
        repaint = false
        if frame:IsShown() then
            frame.list:Repaint()
            frame.pieces:Refresh()
        end
    end)
end)
