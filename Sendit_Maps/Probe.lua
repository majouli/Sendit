--[[
  Probe (diagnostic, English):
  /maps probe        the client's lock of the instance you are in and the bosses marked killed
  /maps probe nav    5 s of the navigation target's screen spot (the map open inside an instance: the
                     locator tracks flight masters) - does it follow the camera when you turn?
]]
local _, ns = ...

local function Nav()
    print("Sendit Maps probe: with the map open inside the instance, turn with the mouse standing still (5 s).")
    local t, wait = 0, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, elapsed)
        t, wait = t + elapsed, wait + elapsed
        if wait < 0.25 then return end
        wait = 0
        local nav = C_Navigation
        if not nav then
            print("no C_Navigation")
            return self:SetScript("OnUpdate", nil)
        end
        local okF, frame = pcall(nav.GetFrame)
        local x, y = "-", "-"
        if okF and frame and frame.GetCenter then
            local okC, cx, cy = pcall(frame.GetCenter, frame)
            if okC then x, y = tostring(cx), tostring(cy) end
        end
        local okS, state = pcall(nav.GetTargetState or function() end)
        local okW, clamped = pcall(nav.WasClampedToScreen or function() end)
        local okD, dist = pcall(nav.GetDistance)
        print(("frame=%s center=%s,%s state=%s clamped=%s distance=%s running=%s"):format(tostring(okF and frame ~= nil),
            x, y, tostring(okS and state), tostring(okW and clamped), tostring(okD and dist), tostring(ns.Locator.IsRunning())))
        if t >= 5 then self:SetScript("OnUpdate", nil) end
    end)
end

function ns.Probe(what)
    if what == "nav" then return Nav() end
    for _, line in ipairs(ns.Kills.Report()) do print("Sendit Maps: " .. line) end
end
