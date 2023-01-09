""" 
Iterators used in Parallel Tempering. Stored in a struct so that 
[`recorder`](@ref)'s can access it when outputting 
sample statistics.

Fields:
$FIELDS
""" 
@kwdef mutable struct Iterators
    """
    Index of the Parallel Tempering adaptation *round*, as defined in 
    [Algorithm 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    Set to zero when when run!() not yet started.
    """
    round::Int = 0

    """
    Number of (exploration, communication) pairs performed 
    so far, corresponds to ``n`` in 
    [Algorithm 1 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    Round ``i`` typically performs ``2^i`` scans. 
    Set to zero when run_one_round!() is not yet started. 
    """
    scan::Int = 0

    # TODO: store round timing
end

function next_round!(pt)
    iterators = pt.shared.iterators
    if iterators.round + 1 ≤ pt.inputs.n_rounds
        iterators.round += 1 
        return true
    else   
        return false
    end
end

function next_scan!(pt)
    # TODO: collect timing information on process=1
    shared = pt.shared
    iterators = pt.shared.iterators
    iterators.scan += 1
    if iterators.scan ≤ 2^iterators.round 
        return true
    else # this round is over, prepare to start new round:
        iterators.scan = 0
        return false
    end
end