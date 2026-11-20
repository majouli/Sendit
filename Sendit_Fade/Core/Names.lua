--[[
  Names: a label and a reload-stable key for every element.
  Label (first hit): the cleaned frame name (addon prefix, tags, "Frame" dropped, words split), else the
  first named descendant's, else the first short text inside, else the kind.
  Key: the frame name, else owner / named descendant or kind / strata / anchor (+ "#n" in creation order).
]]
local _, ns = ...

local Names = {}
ns.Names = Names

local Safe = ns.Safe

local MAX_WALK = 150  -- descendants inspected per anonymous frame
local MAX_TEXT = 32   -- longer texts are sentences, not titles

Names.KIND_LABELS = {
    nameplate = "Nameplate", minimap = "Minimap", chat = "Chat", tooltip = "Tooltip",
    castbar = "Cast bar", auras = "Auras", tracker = "Tracker", actionbar = "Action bar",
    bags = "Bags", unitframe = "Unit frame", bar = "Bar", menu = "Menu", other = "Element",
}

-- kind names in the suite's language; KIND_LABELS stays English (exclusion patterns match it)
function Names.KindLabel(kind)
    return Names.KIND_LABELS[kind] and ns.L["KIND_" .. kind] or kind
end

local function SplitWords(s)
    s = s:gsub("[_%-%.]+", " ")
    s = s:gsub("(%l)(%u)", "%1 %2")    -- fooBar -> foo Bar
    s = s:gsub("(%u)(%u%l)", "%1 %2")  -- CDMBar -> CDM Bar
    s = s:gsub("(%a)(%d)", "%1 %2")    -- Chat1  -> Chat 1
    s = s:gsub("%s+", " ")
    return strtrim(s)
end

function Names.Clean(name)
    local s = ns.Scanner:StripAddonPrefix(name)
    s = s:gsub("^%u%u?%u?%u?%u?_", "")
    if #s > 5 then s = s:gsub("Frame$", "") end
    s = SplitWords(s)
    if s == "" then s = SplitWords(name) end
    return s
end

function Names.Pretty(name)
    return SplitWords(name)
end

local function ShortText(region)
    if Safe.Call(region, "GetObjectType") ~= "FontString" then return nil end
    local t = Safe.Call(region, "GetText")
    if type(t) ~= "string" then return nil end
    t = strtrim((t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    if #t >= 3 and #t <= MAX_TEXT and not t:find("^[%d%s%.,:/%%%-+kKmM]+$") then return t end
end

local function Inspect(root)
    local named, text
    local queue, head = { root }, 1
    while queue[head] and head <= MAX_WALK and not (named and text) do
        local f = queue[head]
        head = head + 1
        if not Safe.IsForbidden(f) then
            if f ~= root and not named then named = Safe.Name(f) end
            if not text then
                for _, region in ipairs(Safe.Regions(f)) do
                    text = ShortText(region)
                    if text then break end
                end
            end
            if #queue < MAX_WALK then
                for _, child in ipairs(Safe.Children(f)) do queue[#queue + 1] = child end
            end
        end
    end
    return named, text
end

local function AnchorSignature(f)
    local ok, point, rel, relPoint = pcall(f.GetPoint, f, 1)
    if not ok then return "free" end
    point, relPoint = Safe.Value(point), Safe.Value(relPoint)
    if type(point) ~= "string" then return "free" end
    local relName = "nil"
    if rel then
        relName = (rel == UIParent and "UIParent")
            or (not Safe.IsForbidden(rel) and Safe.Name(rel))
            or "anon"
    end
    return point .. ">" .. relName .. ":" .. tostring(relPoint)
end

function Names.Describe(e, f)
    if not e.anonymous then
        e.label = Names.Clean(e.name)
        e.signature = e.name
        return
    end
    local named, text = Inspect(f)
    e.label = (named and Names.Clean(named)) or text or Names.KIND_LABELS[e.kind] or "Element"
    e.signature = table.concat({ e.owner, named or e.kind, e.strata, AnchorSignature(f) }, "/")
end

function Names.AssignKeys(elements)
    local seen = {}
    for _, e in ipairs(elements) do
        local n = (seen[e.signature] or 0) + 1
        seen[e.signature] = n
        e.key = n == 1 and e.signature or (e.signature .. "#" .. n)
        if n > 1 and e.anonymous then e.label = e.label .. " " .. n end
    end
end
