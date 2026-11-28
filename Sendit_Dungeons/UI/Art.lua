--[[
  Art: the client's own pictures.
  Art.Screen(texture, d, width, height)   loading screen band cropped to the size; false if none
  Art.Portrait(texture, boss, model)      boss face from a model zoomed to the head (skull if unknown);
                                          a face already showing this boss is not set again
  Art.ShowModel(owner, boss) / HideModel() a slowly turning 3D view beside owner (one shared frame)
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
    local band = math.min(1, height / width * SCREEN_ASPECT)
    local top = math.max(0, 0.45 - band / 2)
    tex:SetTexCoord(0, 1, top, math.min(1, top + band))
    tex:Show()
    return true
end

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

-- A model from the boss's display ID, else its NPC ID (Forever's own bosses).
-- Repaints are frequent: a model already showing this boss is left alone (a reload restarts it).
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

-- A portrait stands still: zoom to the head and freeze the first frame.
function Art.Still(model)
    pcall(model.SetScript, model, "OnModelLoaded", function(self)
        pcall(self.SetPortraitZoom, self, 1)
        pcall(self.FreezeAnimation, self, 0, 0, 0)
    end)
end

local Face
-- tex is masked round: never SetTexCoord on it (the client refuses). A face already showing this boss
-- is left alone (a repaint must not re-zoom the model).
function Art.Portrait(tex, boss, model)
    local display = boss.display or 0
    local key = display > 0 and ("d" .. display) or ("n" .. (boss.npc or 0))
    if tex.senditFace == key and tex.senditShown ~= nil then return tex.senditShown end
    tex.senditFace = key
    tex.senditShown = Face(tex, boss, model, display)
    return tex.senditShown
end

function Face(tex, boss, model, display)
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
