--[[
  ObjectiveLinks: replace literal objective item names with client item links.
  Unmatched names stay available as links below the text (locale/grammar gaps).
  AH labels mean tradable item type, never a claim about current listings.
]]
local _, ns = ...
local Links = {}
ns.ObjectiveLinks = Links
local requested = {}
function Links.Text(id, text)
    local q, extra, seen = ns.quests[id], {}, {}
    for _, entry in ipairs(q and q.objectives and q.objectives.items or {}) do
        local itemID = entry[1]
        if type(itemID) == "number" and not seen[itemID] then
            seen[itemID] = true
            local api = C_Item or {}
            local ok, name, link, _, _, _, _, _, _, _, _, _, _, _, bind
            if api.GetItemInfo then
                ok, name, link, _, _, _, _, _, _, _, _, _, _, _, bind = pcall(api.GetItemInfo, itemID)
            end
            if ok and not (issecretvalue and (issecretvalue(name) or issecretvalue(link) or issecretvalue(bind))) and name then
                local label = (link or ("|Hitem:" .. itemID .. "|h[" .. name .. "]|h"))
                if bind == 0 or bind == 2 then label = label .. " (" .. ns.L.ahItem .. ")" end
                local first, last = text:find(name, 1, true)
                if first then text = text:sub(1, first - 1) .. label .. text:sub(last + 1)
                else extra[#extra + 1] = label end
            else
                extra[#extra + 1] = "|Hitem:" .. itemID .. "|h[#" .. itemID .. "]|h"
                if not requested[itemID] and api.RequestLoadItemDataByID then
                    requested[itemID] = true
                    pcall(api.RequestLoadItemDataByID, itemID)
                end
            end
        end
    end
    return text .. (#extra > 0 and ("\n" .. table.concat(extra, ", ")) or "")
end
function Links.Attach(frame)
    frame:SetHyperlinksEnabled(true)
    frame:SetScript("OnHyperlinkEnter", function(self, link)
        if not link:match("^item:%d+") then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    frame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
end
