--[[
  Model: the character in 3D wearing the outfit - drag turns it, the wheel zooms, a right click
  resets the view. A soft sky behind it.
  Model.Create(parent) -> stage;  stage:Load() (the character, each time the window opens) /
  stage:Dress({ [slot] = itemID }) / stage:ResetView() / stage.tries[slot] = { itemID, way, result }
  An item is tried on as its link, then "item:ID", then its transmog source; a refused way (a
  non-zero try-on reason) falls through to the next. The client loads the character late: the
  outfit is worn again on its load and shortly after Load, a missing item once its data arrives.
  Try-ons load the model too: those loads never re-wear (else it flickers). A new outfit tries on
  only its changed slots.
]]
local _, ns = ...
local T = Sendit.Theme
local Slots = ns.Slots
local Model = {}
ns.Model = Model
local TURN = 0.012      -- radians per pixel dragged
local ZOOM_STEP, ZOOM_MAX = 0.08, 0.7
local AGAIN = { 0.2, 0.8 }  -- seconds after Load: wear the outfit again (the character loads late)

local function Ways(id)
    local _, link = ns.Read(C_Item.GetItemInfo, id)
    local _, source = ns.Read(C_TransmogCollection and C_TransmogCollection.GetItemInfo, id)
    return { { "link", type(link) == "string" and link or nil }, { "item", "item:" .. id },
        { "source", type(source) == "number" and source or nil } }
end

-- result: nil (old clients return nothing) or 0 = worn; any other number = refused, try the next way
local function TryOn(m, id, hand, tries, slot)
    for _, way in ipairs(Ways(id)) do
        if way[2] then
            local ok, result
            if hand then ok, result = pcall(m.TryOn, m, way[2], hand) else ok, result = pcall(m.TryOn, m, way[2]) end
            tries[slot] = { id, way[1], ok and (result == nil and "ok" or result) or "error" }
            if ok and (result == nil or result == 0) then return end
        end
    end
end

local function Cached(id)
    local fn = C_Item.IsItemDataCachedByID
    if not fn then return true end
    local ok, has = pcall(fn, id)
    return not ok or has == true
end

local function Put(stage, slot, id)
    if not Cached(id) then
        stage.missing[id] = true
        if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    TryOn(stage.model, id, Slots.Hand(slot), stage.tries, slot)
end

-- the whole outfit from scratch (the character was loaded, or a slot was emptied)
local function Wear(stage)
    local m = stage.model
    pcall(m.Undress, m)
    wipe(stage.tries)
    wipe(stage.missing)
    for _, slot in ipairs(Slots.ORDER) do
        local id = stage.outfit[slot]
        if id then Put(stage, slot, id) end
    end
    stage.worn = {}
    for slot, id in pairs(stage.outfit) do stage.worn[slot] = id end
    pcall(m.SetSheathed, m, false)
end

local function View(stage)
    local m = stage.model
    pcall(m.SetFacing, m, stage.facing)
    pcall(m.SetPortraitZoom, m, stage.zoom)
    pcall(m.SetCamDistanceScale, m, 1 - stage.zoom * 0.55)
end

function Model.Create(parent)
    local stage = CreateFrame("Frame", nil, parent)
    stage.facing, stage.zoom, stage.outfit, stage.tries, stage.worn, stage.missing = 0, 0, {}, {}, {}, {}
    local sky = T.Fill(stage, "sky", "BACKGROUND")
    sky:SetAllPoints()
    T.Gradient(sky, "sky", "bg", 0.9, 0.2)
    local ok, m = pcall(CreateFrame, "DressUpModel", nil, stage)
    if not ok or not m then m = CreateFrame("PlayerModel", nil, stage) end
    m:SetPoint("TOPLEFT", 0, -10)
    m:SetPoint("BOTTOMRIGHT", 0, 10)
    stage.model = m
    stage.hint = T.Text(stage, "caption", "textMuted")
    stage.hint:SetPoint("BOTTOM", 0, 8)
    stage.hint:SetText(ns.L.modelHint)

    pcall(m.SetScript, m, "OnModelLoaded", function()
        if not stage.loading then return end
        stage.loading = false
        Wear(stage)
        View(stage)
    end)

    -- a missing item's data arrived: put on just that piece
    pcall(m.RegisterEvent, m, "GET_ITEM_INFO_RECEIVED")
    m:SetScript("OnEvent", function(_, _, id)
        if not stage.missing[id] then return end
        stage.missing[id] = nil
        if not stage:IsVisible() then return end
        for slot, worn in pairs(stage.worn) do
            if worn == id then TryOn(m, id, Slots.Hand(slot), stage.tries, slot) end
        end
    end)

    m:EnableMouse(true)
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        stage.dragX = GetCursorPosition()
    end)
    m:SetScript("OnUpdate", function()
        if not stage.dragX then return end
        local x = GetCursorPosition()
        stage.facing = stage.facing + (x - stage.dragX) * TURN
        stage.dragX = x
        pcall(m.SetFacing, m, stage.facing)
    end)
    m:SetScript("OnMouseWheel", function(_, delta)
        stage.zoom = math.max(0, math.min(ZOOM_MAX, stage.zoom + delta * ZOOM_STEP))
        View(stage)
    end)
    m:SetScript("OnMouseUp", function(_, button)
        stage.dragX = nil
        if button == "RightButton" then stage:ResetView() end
    end)

    -- a full Wear only when a slot was emptied
    function stage:Dress(outfit)
        self.outfit = {}
        for slot, id in pairs(outfit) do self.outfit[slot] = id end
        if not self:IsShown() then return end
        for slot in pairs(self.worn) do
            if not self.outfit[slot] then return Wear(self) end
        end
        for _, slot in ipairs(Slots.ORDER) do
            local id = self.outfit[slot]
            if id and self.worn[slot] ~= id then
                Put(self, slot, id)
                self.worn[slot] = id
            end
        end
    end

    function stage:Load()
        self.loading = true
        pcall(m.SetUnit, m, "player")
        Wear(self)
        View(self)
        for _, delay in ipairs(AGAIN) do
            C_Timer.After(delay, function()
                if delay == AGAIN[#AGAIN] then self.loading = false end  -- its load never came: stop waiting
                if self:IsVisible() then Wear(self) end
            end)
        end
    end

    function stage:ResetView()
        self.facing, self.zoom = 0, 0
        View(self)
    end
    return stage
end
