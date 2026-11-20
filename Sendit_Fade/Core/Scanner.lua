--[[
  Scanner: every top-level element (UIParent children and parentless frames), whatever addon made it;
  frames without size, children or regions are skipped. Owner (first hit): GetSourceLocation, taint
  of the global name, name prefix of a loaded addon, first identifiable descendant.
  Element: { frame, name, label, key, owner, kind, strata, visible, width, height, protected, anonymous }
]]
local _, ns = ...

local Scanner = {}
ns.Scanner = Scanner

local Safe = ns.Safe

local MAX_DESCENDANTS = 300
local MIN_FAMILY = 4  -- shortest addon name that can head a family
local UNKNOWN = "Unknown"
local BLIZZARD = "Blizzard"

local function Normalize(s)
    return (s:lower():gsub("[^%w]", ""))
end

local function AddonLabel(addon)
    if addon:find("^Blizzard_") then return BLIZZARD end
    return addon
end

local addonIndex = {}  -- { name, key }, longest first

local function BuildAddonIndex()
    wipe(addonIndex)
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) then
            addonIndex[#addonIndex + 1] = { name = name, key = Normalize(name) }
        end
    end
    table.sort(addonIndex, function(a, b) return #a.key > #b.key end)
end

function Scanner:StripAddonPrefix(name)
    local lname = name:lower()
    for _, a in ipairs(addonIndex) do
        if #a.name < #name and lname:sub(1, #a.name) == a.name:lower() then
            return name:sub(#a.name + 1)
        end
    end
    return name
end

-- shortest other loaded addon prefixing the owner ("SuiteUIActionBars" -> "SuiteUI")
function Scanner:FamilyOf(owner)
    local lowner, family = owner:lower(), owner
    for _, a in ipairs(addonIndex) do  -- longest first: the last hit is the shortest
        if #a.name >= MIN_FAMILY and #a.name < #owner and lowner:sub(1, #a.name) == a.name:lower() then
            family = a.name
        end
    end
    return family
end

local function OwnerFromSource(f)
    local loc = Safe.Call(f, "GetSourceLocation")
    if type(loc) ~= "string" then return nil end
    local addon = loc:match("[Aa]dd[Oo]ns[/\\]([^/\\]+)")
    if addon then return AddonLabel(addon) end
    if loc:find("FrameXML") or loc:find("SharedXML") then return BLIZZARD end
end

local function OwnerFromGlobal(f, name)
    if not name or _G[name] ~= f then return nil end
    local secure, taint = issecurevariable(name)
    if secure then return BLIZZARD end
    if taint and taint ~= "" then return AddonLabel(taint) end
end

local function OwnerFromPrefix(name)
    if not name then return nil end
    local key = Normalize(name)
    for _, a in ipairs(addonIndex) do
        if key:sub(1, #a.key) == a.key then return AddonLabel(a.name) end
    end
end

local function OwnerOf(f)
    local name = Safe.Name(f)
    return OwnerFromSource(f) or OwnerFromGlobal(f, name) or OwnerFromPrefix(name)
end

local function OwnerFromDescendants(root)
    local queue, head = { root }, 1
    while queue[head] and head <= MAX_DESCENDANTS do
        local f = queue[head]
        head = head + 1
        if not Safe.IsForbidden(f) and not ns.ownFrames[f] then
            if f ~= root then
                local owner = OwnerOf(f)
                if owner then return owner end
            end
            if #queue < MAX_DESCENDANTS then
                for _, child in ipairs(Safe.Children(f)) do queue[#queue + 1] = child end
            end
        end
    end
end

-- kind: heuristic on the name, first match wins
local KIND_PATTERNS = {
    { "nameplate", "nameplate" },
    { "minimap",   "minimap" },
    { "chat",      "chat" },
    { "tooltip",   "tooltip" },
    { "cast",      "castbar" },
    { "buff",      "auras" },
    { "aura",      "auras" },
    { "quest",     "tracker" },
    { "objective", "tracker" },
    { "tracker",   "tracker" },
    { "actionbar", "actionbar" },
    { "multibar",  "actionbar" },
    { "bag",       "bags" },
    { "container", "bags" },
    { "player",    "unitframe" },
    { "target",    "unitframe" },
    { "party",     "unitframe" },
    { "raid",      "unitframe" },
    { "bar",       "bar" },
    { "menu",      "menu" },
}

local function KindOf(f, name)
    if Safe.Call(f, "GetAttribute", "unit") then return "unitframe" end
    local lname = name:lower()
    for _, p in ipairs(KIND_PATTERNS) do
        if lname:find(p[1], 1, true) then return p[2] end
    end
    return "other"
end

local function CollectRoots()
    local roots, seen = {}, {}
    local function Add(f)
        if f and not seen[f] then
            seen[f] = true
            roots[#roots + 1] = f
        end
    end
    for _, child in ipairs(Safe.Children(UIParent)) do Add(child) end
    local f = EnumerateFrames()
    while f do
        if f ~= UIParent and f ~= WorldFrame and not Safe.IsForbidden(f) and not Safe.Parent(f) then
            Add(f)
        end
        f = EnumerateFrames(f)
    end
    return roots
end

local function IsVisual(f)
    local w, h = Safe.Size(f)
    if w and w * h > 0 then return true end
    return (Safe.Call(f, "GetNumChildren") or 0) > 0 or (Safe.Call(f, "GetNumRegions") or 0) > 0
end

local function Describe(f)
    local name = Safe.Name(f)
    local display = name or Safe.Call(f, "GetDebugName") or tostring(f)
    local w, h = Safe.Size(f)
    local e = {
        frame     = f,
        name      = display,
        anonymous = name == nil,
        owner     = OwnerOf(f) or OwnerFromDescendants(f) or UNKNOWN,
        visible   = Safe.IsVisible(f),
        width     = math.floor((w or 0) + 0.5),
        height    = math.floor((h or 0) + 0.5),
        strata    = Safe.Call(f, "GetFrameStrata") or "MEDIUM",
        protected = Safe.Call(f, "IsProtected") == true,
    }
    e.kind = KindOf(f, display)
    ns.Names.Describe(e, f)
    return e
end

function Scanner:Scan()
    BuildAddonIndex()
    local r = { elements = {}, total = 0, visible = 0, byOwner = {}, byKind = {} }

    for _, f in ipairs(CollectRoots()) do
        if not ns.ownFrames[f] and not Safe.IsForbidden(f) and IsVisual(f) then
            local e = Describe(f)
            r.elements[#r.elements + 1] = e
            r.total = r.total + 1
            if e.visible then r.visible = r.visible + 1 end
            r.byOwner[e.owner] = (r.byOwner[e.owner] or 0) + 1
            r.byKind[e.kind] = (r.byKind[e.kind] or 0) + 1
        end
    end

    ns.Names.AssignKeys(r.elements)  -- needs creation order: before sorting

    table.sort(r.elements, function(a, b)
        if a.visible ~= b.visible then return a.visible end
        if a.owner ~= b.owner then return a.owner < b.owner end
        return a.label < b.label
    end)

    self.last = r
    return r
end

local MAX_LINES = 50

local function SortedCounts(t)
    local list = {}
    for k, v in pairs(t) do list[#list + 1] = { k, v } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    return list
end

function Scanner:PrintSummary(r)
    ns.Print(("%d elements, %d visible"):format(r.total, r.visible))
    local parts = {}
    for i, kv in ipairs(SortedCounts(r.byOwner)) do
        if i > 15 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = kv[1] .. " " .. kv[2]
    end
    print("  By addon: " .. table.concat(parts, ", "))
    parts = {}
    for _, kv in ipairs(SortedCounts(r.byKind)) do parts[#parts + 1] = kv[1] .. " " .. kv[2] end
    print("  By type: " .. table.concat(parts, ", "))
end

function Scanner:PrintList(filter)
    local r = self.last or self:Scan()
    filter = filter ~= "" and filter:lower() or nil
    local shown, matched = 0, 0
    for _, e in ipairs(r.elements) do
        local hay = (e.label .. " " .. e.name .. " " .. e.owner .. " " .. e.kind):lower()
        if not filter or hay:find(filter, 1, true) then
            matched = matched + 1
            if shown < MAX_LINES then
                shown = shown + 1
                print(("  %s %s |cffaaaaaa[%s] (%s, %s, %s, %dx%d%s)|r"):format(
                    e.visible and "|cff00ff00+|r" or "|cff666666-|r",
                    e.label, e.key, e.owner, e.kind, e.strata, e.width, e.height,
                    e.protected and ", protected" or ""))
            end
        end
    end
    if matched > shown then
        print(("  ... and %d more (narrow it down with /fa list <text>)"):format(matched - shown))
    elseif matched == 0 then
        ns.Print("No matching elements.")
    end
end
