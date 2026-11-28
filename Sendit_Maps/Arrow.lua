--[[
  Arrow: the player's arrow on a map view. It glides to each new position (a located fix wobbles a few
  yards between readings) and turns smoothly to a located facing (it wobbles too), at once with the turn
  keys, and to where the camera looks while the mouse steers (Camera); the client's own facing, when it gives one, is taken every frame. A jump farther than SNAP is taken at once.
  Arrow.Create(view[, onMove(x, y)]) -> arrow;  arrow:Target(x, y, facing) / arrow:Hide()
]]
local _, ns = ...
local Arrow = {}
ns.Arrow = Arrow

local SIZE = 28
local GLIDE = 8   -- per second: the share of the remaining way covered
local SNAP = 40   -- map pixels
local TURN = 10   -- per second: the share of the remaining turn covered
local PI2 = math.pi * 2

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function Target(self, x, y, facing)
    if not self:IsShown() or not self.mapX or math.abs(x - self.mapX) + math.abs(y - self.mapY) > SNAP then
        self.mapX, self.mapY = x, y
    end
    self.toX, self.toY = x, y
    if facing then
        self.toAngle = facing
        if not self.angle then
            self.angle = facing
            self.arrow:SetRotation(facing)
        end
    end
    self:Show()
    self.view:Place(self)
    if self.onMove then self.onMove(self.mapX, self.mapY) end
end

function Arrow.Create(view, onMove)
    local arrow = CreateFrame("Frame", nil, view.viewport)
    arrow:SetSize(SIZE, SIZE)
    arrow:SetFrameLevel(view.viewport:GetFrameLevel() + 680)
    arrow.arrow = arrow:CreateTexture(nil, "OVERLAY")
    arrow.arrow:SetAllPoints()
    arrow.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow.view, arrow.onMove, arrow.Target = view, onMove, Target
    arrow:Hide()
    view:Add(arrow)
    arrow:SetScript("OnUpdate", function(self, elapsed)
        local facing = GetPlayerFacing and GetPlayerFacing()
        local camera, seen = ns.Camera.Yaw()
        if camera and seen ~= self.cameraAt then  -- the mouse steers: face where the camera looks
            self.cameraAt, self.toAngle = seen, camera
            self.angle = self.angle or camera
        end
        if Plain(facing) then
            self.angle, self.toAngle = facing, facing
            self.arrow:SetRotation(facing)
        elseif self.angle and ns.Motion.Turning() ~= 0 then
            -- a key turn: the client's turn speed, at once (a located facing comes only when walking)
            self.angle = self.angle + ns.Motion.Turning() * ns.Motion.TURN_RATE * elapsed
            self.toAngle = self.angle
            self.arrow:SetRotation(self.angle)
        elseif self.toAngle and self.angle then
            local d = (self.toAngle - self.angle + math.pi) % PI2 - math.pi  -- the short way round
            if math.abs(d) > 0.01 then
                self.angle = self.angle + d * math.min(1, elapsed * TURN)
                self.arrow:SetRotation(self.angle)
            end
        end
        if not self.toX then return end
        local dx, dy = self.toX - self.mapX, self.toY - self.mapY
        if math.abs(dx) + math.abs(dy) < 0.05 then return end
        local k = math.min(1, elapsed * GLIDE)
        self.mapX, self.mapY = self.mapX + dx * k, self.mapY + dy * k
        self.view:Place(self)
        if self.onMove then self.onMove(self.mapX, self.mapY) end
    end)
    return arrow
end
