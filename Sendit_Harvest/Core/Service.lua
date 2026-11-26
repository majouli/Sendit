local _, ns = ...

Sendit.Provide("disenchant", {
    Knows = function() return ns.Professions.Knows("disenchant") == true end,
    Value = function(link)
        local value, priced = ns.DribblerValue.ForItem(link)
        return value, priced
    end,
})
