--[[
  Verdict: whether an item is an upgrade the character can wear now (Compare.Evaluate: a gain of the
  primary metric, no level gate) - what the green arrows show. Per link, cached until gear, level, spec
  or the enemy level change; items the client has not loaded wait for it, and only PER_STEP items are
  rated per step so a full bag never stalls a frame.
  Verdict.Of(link) -> true | false | nil (not known yet: asked, Verdict.OnReady fires once known)
  Verdict.OnReady(fn(link)) / OnReset(fn) (all cached verdicts dropped);  Verdict.On() -> arrows wanted
  (account: Sendit_UpgradeDB.arrows, nil = on)
]]
local _, ns = ...
local Verdict = {}
ns.Verdict = Verdict

local PER_STEP, STEP, RETRY = 8, 0.05, 2
local cache, queue, queued = {}, {}, {}
local ready, reset = {}, {}
local running = false
local isSecret = issecretvalue or function() return false end

function Verdict.OnReady(fn) ready[#ready + 1] = fn end
function Verdict.OnReset(fn) reset[#reset + 1] = fn end
function Verdict.On() return not (ns.db and ns.db.arrows == false) end

-- true / false, or nil while the item is not loaded
local function Rate(link)
    local ok, r = pcall(ns.Compare.Evaluate, link)
    if not ok or not r then return false end
    if r.status == "loading" or r.status == "nodata" then return nil end  -- item or character not there yet
    return r.status == "ok" and r.primary ~= nil and type(r.primary.pct) == "number" and r.primary.pct > 0
        and not r.levelGate
end

local function Step()
    local done = 0
    while done < PER_STEP and #queue > 0 do
        local link = table.remove(queue, 1)
        queued[link] = nil
        local v = Rate(link)
        if v == nil then
            C_Timer.After(RETRY, function()
                if cache[link] == nil and not queued[link] then
                    queued[link] = true
                    queue[#queue + 1] = link
                    if not running then running = true; C_Timer.After(STEP, Step) end
                end
            end)
        else
            cache[link] = v
            for _, fn in ipairs(ready) do fn(link) end
        end
        done = done + 1
    end
    if #queue > 0 then C_Timer.After(STEP, Step) else running = false end
end

function Verdict.Of(link)
    if type(link) ~= "string" or isSecret(link) or not Verdict.On() then return false end
    local v = cache[link]
    if v ~= nil then return v end
    if not queued[link] then
        queued[link] = true
        queue[#queue + 1] = link
        if not running then
            running = true
            C_Timer.After(0, Step)
        end
    end
    return nil
end

function Verdict.Reset()
    cache = {}
    for _, fn in ipairs(reset) do fn() end
end

local service = Sendit.Service("upgrade")
if service then service.OnChange(Verdict.Reset) end
