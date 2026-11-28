--[[
  View: zoom and pan of a canvas inside a clipping viewport; marks stay their size on screen.
  View.Create(viewport, canvas[, fixed]) -> view   fixed: no mouse handling (the compact map has its own);
  view.canvas may be swapped (the drawn map or the room tiles)
  view:Fit([x, y, w, h])   whole map, or that map rect          view:ZoomAt(factor) at the cursor
  view:Add(mark)           mark.mapX / mapY follow the map (dx / dy: a screen offset)   view:Apply()  after a change
  view:Place(mark)         only that mark (the player, every tick)
  Mouse: wheel zooms, left drag pans, a right click fits the map.
]]
local _, ns = ...
local View = {}
ns.View = View

local MIN_FIT, MAX_ZOOM = 0.5, 6  -- zoom out to half the fitting size at most

local Methods = {}

function Methods:Size()
    return math.max(1, self.viewport:GetWidth()), math.max(1, self.viewport:GetHeight())
end

function Methods:Apply()
    local canvas = self.canvas
    canvas:SetScale(self.zoom)
    canvas:SetZoom(self.zoom)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", self.viewport, "TOPLEFT", self.x / self.zoom, -self.y / self.zoom)
    for _, mark in ipairs(self.marks) do
        if mark:IsShown() and mark.mapX then
            mark:ClearAllPoints()
            mark:SetPoint("CENTER", self.viewport, "TOPLEFT", self.x + mark.mapX * self.zoom + (mark.dx or 0),
                -(self.y + mark.mapY * self.zoom) - (mark.dy or 0))
        end
    end
end

function Methods:FitZoom()
    local map = self.canvas.map
    local w, h = self:Size()
    return math.min(w / map.w, h / map.h)
end

function Methods:Fit(left, top, width, height)
    local map = self.canvas.map
    if not left then
        local focus = map.focus
        if focus then left, top, width, height = focus[1], focus[2], focus[3], focus[4]
        else left, top, width, height = 0, 0, map.w, map.h end
    end
    local w, h = self:Size()
    self.zoom = math.min(MAX_ZOOM, w / width, h / height)
    self.x = (w - width * self.zoom) / 2 - left * self.zoom
    self.y = (h - height * self.zoom) / 2 - top * self.zoom
    self:Apply()
end

function Methods:Cursor()
    local x, y = GetCursorPosition()
    local scale = self.viewport:GetEffectiveScale()
    return x / scale - self.viewport:GetLeft(), self.viewport:GetTop() - y / scale
end

function Methods:ZoomAt(factor)
    local cx, cy = self:Cursor()
    local zoom = math.max(self:FitZoom() * MIN_FIT, math.min(MAX_ZOOM, self.zoom * factor))
    local mx, my = (cx - self.x) / self.zoom, (cy - self.y) / self.zoom
    self.zoom = zoom
    self.x, self.y = cx - mx * zoom, cy - my * zoom
    self:Apply()
end

function Methods:CenterOn(mx, my)
    local w, h = self:Size()
    self.x, self.y = w / 2 - mx * self.zoom, h / 2 - my * self.zoom
    self:Apply()
end

function Methods:Add(mark) self.marks[#self.marks + 1] = mark end

function Methods:Place(mark)
    mark:ClearAllPoints()
    mark:SetPoint("CENTER", self.viewport, "TOPLEFT", self.x + mark.mapX * self.zoom + (mark.dx or 0),
        -(self.y + mark.mapY * self.zoom) - (mark.dy or 0))
end

function View.Create(viewport, canvas, fixed)
    local view = { viewport = viewport, canvas = canvas, marks = {}, zoom = 1, x = 0, y = 0 }
    for name, fn in pairs(Methods) do view[name] = fn end
    viewport:SetClipsChildren(true)
    if fixed then return view end
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function(_, delta)
        if view.canvas.map then view:ZoomAt(delta > 0 and 1.2 or 1 / 1.2) end
    end)
    viewport:SetScript("OnMouseDown", function(_, button)
        if not view.canvas.map then return end
        if button == "RightButton" then return view:Fit() end
        local cx, cy = view:Cursor()
        view.drag = { cx = cx, cy = cy, x = view.x, y = view.y }
    end)
    viewport:SetScript("OnMouseUp", function() view.drag = nil end)
    viewport:SetScript("OnUpdate", function()
        local d = view.drag
        if not d then return end
        if not IsMouseButtonDown("LeftButton") then view.drag = nil return end
        local cx, cy = view:Cursor()
        view.x, view.y = d.x + cx - d.cx, d.y + cy - d.cy
        view:Apply()
    end)
    return view
end
