function get_dimension(model::DynamicPPL.Model)
    vi = DynamicPPL.VarInfo(SplittableRandom(1), model)
    get_dimension(DynamicPPL.link(vi, model))
end

get_dimension(vi::DynamicPPL.VarInfo) = length(DynamicPPL.internal_values_as_vector(vi))


function flatten!(vi::DynamicPPL.VarInfo, dest::Array)
    vals = DynamicPPL.internal_values_as_vector(vi)
    copyto!(dest, firstindex(dest), vals, firstindex(vals), length(vals))
    return dest
end
