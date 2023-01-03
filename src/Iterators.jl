""" 
Iterators used in PT. Stored in a struct so that 
[`recorder`](@ref)'s can access it when outputting 
sample statistics.

Fields:
$FIELDS
""" 
@kwdef mutable struct PT_Iterators
    """
    Index of the PT adaptation *round*, as defined in 
    [Algorithm 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    """
    round::Int = 0

    """
    Number of (exploration, communication) pairs performed 
    so far, corresponds to ``n`` in 
    [Algorithm 1 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    Round ``i`` typically performs ``2^i`` scans. 
    """
    scan::Int = 0
end

function next_round!(pt)
    globals = pt.globals
    iterators = globals.iterators
    # TODO: options in pt.globals.inputs based on TE-based mcse 
    iterators.round += 1 
    return iterators.round ≤ inputs.n_rounds
end

function next_scan!(pt)
    # TODO: collect timing information on process=1
    globals = pt.globals 
    iterators = globals.iterators
    iterators.scan += 1
    if iterators.scan ≤ 2^iterators.round 
        return true
    else # this round is over, prepare to start new round:
        iterators.round = 0
        iterators.scan = 0
        return false
    end
end