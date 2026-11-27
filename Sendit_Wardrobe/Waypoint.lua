--[[
  Waypoint: puts Blizzard's own map pin (with navigation) on a place; where the client cannot, the
  place goes to the chat. Waypoint.Set(uiMap, x, y, title) -> true when the pin was set
  Waypoint.Zone(uiMap) -> the client's map name | nil
]]
local _, ns = ...
local Waypoint = {}
ns.Waypoint = Waypoint

function Waypoint.Zone(map)
    local info = map and ns.Read(C_Map and C_Map.GetMapInfo, map)
    return type(info) == "table" and type(info.name) == "string" and info.name or nil
end

local function Native(map, x, y)
    local api, point = C_Map, _G["UiMapPoint"]
    if not (api and api.SetUserWaypoint and point and point.CreateFromCoordinates) then return false end
    if api.CanSetUserWaypointOnMap and ns.Read(api.CanSetUserWaypointOnMap, map) ~= true then return false end
    return (pcall(function()
        if api.ClearUserWaypoint then api.ClearUserWaypoint() end
        api.SetUserWaypoint(point.CreateFromCoordinates(map, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end))
end

function Waypoint.Set(map, x, y, title)
    if not (map and x and y) then return false end
    local ok = Native(map, x, y)
    local where = ("%s (%.1f, %.1f)"):format(Waypoint.Zone(map) or "?", x * 100, y * 100)
    Sendit.Print((ok and ns.L.waypointSet or ns.L.waypointAt):format(title or "", where))
    return ok
end
