local _, ns = ...

function ns.Plain(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end
