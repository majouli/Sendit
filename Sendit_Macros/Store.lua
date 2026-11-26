--[[
  Store: puts a built macro into the client's macro list and on the cursor. A macro with the same text
  is used again (never a second copy, never someone else's macro changed); a new one goes into the
  character's macros, else the account's.
  Store.Find(body) -> index | nil;  Store.Pickup(macro) -> true | nil, "combat" | "full"
]]
local _, ns = ...
local Store = {}
ns.Store = Store

local function Limits()
    return _G["MAX_ACCOUNT_MACROS"] or 120, _G["MAX_CHARACTER_MACROS"] or 18
end

local function Trim(s) return (s or ""):gsub("%s+$", "") end

function Store.Find(body)
    local account, char = GetNumMacros()
    local maxAccount = Limits()
    local want = Trim(body)
    for i = 1, account or 0 do
        if Trim(select(3, GetMacroInfo(i))) == want then return i end
    end
    for i = maxAccount + 1, maxAccount + (char or 0) do
        if Trim(select(3, GetMacroInfo(i))) == want then return i end
    end
end

local function Create(m)
    local account, char = GetNumMacros()
    local maxAccount, maxChar = Limits()
    local perCharacter
    if (char or 0) < maxChar then
        perCharacter = true
    elseif (account or 0) >= maxAccount then
        return nil
    end
    local ok, index = pcall(CreateMacro, m.name, m.macroIcon, m.body, perCharacter)
    if ok and index then return index end
end

function Store.Pickup(m)
    if InCombatLockdown() then return nil, "combat" end
    local index = Store.Find(m.body) or Create(m)
    if not index then return nil, "full" end
    PickupMacro(index)
    return true
end
