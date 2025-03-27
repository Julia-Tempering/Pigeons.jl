function get_dimension(model::DynamicPPL.Model) 
    vi = DynamicPPL.VarInfo(SplittableRandom(1), model)
    get_dimension(DynamicPPL.link(vi, model))
end

get_dimension(vi::DynamicPPL.TypedVarInfo) = sum(meta -> sum(length, meta.ranges), vi.metadata)

function flatten!(vi::DynamicPPL.TypedVarInfo, dest::Array)
    i = firstindex(dest)
    for meta in vi.metadata
        vals = meta.vals
        for r in meta.ranges
            N = length(r)
            copyto!(dest, i, vals, first(r), N)
            i += N
        end
    end
    return dest
end
