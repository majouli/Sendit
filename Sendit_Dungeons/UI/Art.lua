--[[
  Art: the client's own pictures, nothing shipped with the addon.
    Art.Screen(texture, d, width, height)  the dungeon's loading screen, the
        band that fits width x height cropped from its middle (loading screens
        are 4:3); false when the dungeon has none (world bosses)
    Art.Portrait(texture, boss, model)  the boss's face: the portrait texture
        call when the client has one, else the model frame zoomed to the
        head; a skull icon when the model is unknown (Forever's own bosses)
    Art.ShowModel(owner, boss) / HideModel()  a 3D view of the boss beside
        owner, turning slowly - one shared frame, only while hovered
]]
local _, ns = ...
local T, S = Sendit.Theme, ns.Style
local Art = {}
ns.Art = Art
local SCREEN_ASPECT = 4 / 3
local FALLBACK = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

function Art.Screen(tex, d, width, height)
    if not d or not d.art or d.art == 0 or width <= 0 or height <= 0 then
        tex:Hide()
        return false
    end
    tex:SetTexture(d.art)
    local band = math.min(1, height / width * SCREEN_ASPECT)  -- share of the picture's height
    local top = math.max(0, 0.45 - band / 2)
    tex:SetTexCoord(0, 1, top, math.min(1, top + band))
    tex:Show()
    return true
end

-- Square crop for the list thumbnail.
function Art.Thumb(tex, d)
    if not d or not d.art or d.art == 0 then
        tex:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end
    tex:SetTexture(d.art)
    local h = 0.42 * SCREEN_ASPECT
    tex:SetTexCoord(0.29, 0.71, 0.45 - h / 2, 0.45 + h / 2)
end

-- A model from the boss's display ID, or - Forever's own bosses, NPC IDs
-- collected in tools/data/forever_npcs.csv - from its NPC ID (the client
-- loads that creature's model itself).
-- The window repaints often (every item icon that arrives, every boost step):
-- a model already showing this boss is left alone - loading it again made the
-- portraits shake until the last icon had arrived (seen in game).
local function Load(model, boss)
    local key = (boss.display or 0) > 0 and ("d" .. boss.display) or (boss.npc or 0) > 0 and ("n" .. boss.npc) or nil
    if not key then model.senditKey = nil return false end
    if model.senditKey == key then return true end
    local ok
    if key:sub(1, 1) == "d" then ok = pcall(model.SetDisplayInfo, model, boss.display)
    else ok = pcall(model.SetCreature, model, boss.npc) end
    model.senditKey = ok and key or nil
    return ok
end
Art.Load = Load

-- A portrait stands still: the idle animation made the zoomed faces shake
-- (seen in game) - once loaded, zoom to the head and freeze the first frame.
function Art.Still(model)
    -- guarded: a client without the OnModelLoaded handler must not break the window
    pcall(model.SetScript, model, "OnModelLoaded", function(self)
        pcall(self.SetPortraitZoom, self, 1)
        pcall(self.FreezeAnimation, self, 0, 0, 0)
    end)
end

-- tex is masked round: never SetTexCoord on it (the client refuses - seen in game).
-- Forever has no SetPortraitTextureFromCreatureDisplayID that works (it failed in
-- game): the face comes from a small model frame zoomed to the head instead.
function Art.Portrait(tex, boss, model)
    local display = boss.display or 0
    local fn = _G["SetPortraitTextureFromCreatureDisplayID"]
    if model then pcall(model.SetPortraitZoom, model, 1) end
    if display > 0 and type(fn) == "function" and pcall(fn, tex, display) then
        if model then model:Hide() end
        tex:Show()
        return true
    end
    if model and Load(model, boss) then
        model:Show()
        tex:Hide()
        return true
    end
    if model then model:Hide() end
    tex:SetTexture(FALLBACK)
    tex:Show()
    return false
end
Art.MASK = MASK

local view
local function View()
    if view then return view end
    view = CreateFrame("Frame", nil, UIParent)
    Sendit.ownFrames[view] = true
    view:SetSize(240, 280)
    view:SetFrameStrata("TOOLTIP")
    T.Fill(view, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(view, "accent")
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, view)
    if ok and model then
        model:SetPoint("TOPLEFT", 6, -6)
        model:SetPoint("BOTTOMRIGHT", -6, 26)
        view.model = model
    end
    view.name = T.Text(view, "label", "accent")
    view.name:SetPoint("BOTTOM", 0, 8)
    view.facing = 0
    view:SetScript("OnUpdate", function(self, elapsed)
        if not self.model then return end
        self.facing = (self.facing + elapsed * 0.6) % (2 * math.pi)
        pcall(self.model.SetFacing, self.model, self.facing)
    end)
    view:Hide()
    return view
end

function Art.ShowModel(owner, boss)
    local v = View()
    if not v.model or not Load(v.model, boss) then return end
    v.name:SetText(ns.Database.BossName(boss))
    v:ClearAllPoints()
    v:SetPoint("RIGHT", owner, "LEFT", -10, 0)
    v.facing = 0
    v:Show()
end

function Art.HideModel() if view then view:Hide() end end
