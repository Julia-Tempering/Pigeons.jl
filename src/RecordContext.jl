"""
Passed to [`record!()`](@ref) to provide the following 
context to the [`recorder`](@ref):

$FIELDS
"""
mutable struct RecordContext
    """
    Index of the PT adaptation *round*, as defined in 
    [Algorithm 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    """
    round::Int 

    """
    Number of (exploration, communication) pairs performed 
    so far, corresponds to ``n`` in 
    [Algorithm 1 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    Round ``i`` typically performs ``2^i`` scans. 
    """
    scan::Int

    """
    Folder to write output to, which is unique to 
    this execution but shared across all MPI processes. Typically a subfolder 
    of `results/all`. 
    """
    output_folder::String

    """
    [`LoadBalance`](@ref) object.
    """
    load::LoadBalance
end

function output_file(context::RecordContext, path_relative_to_output_folder)
    path = context.output_folder/path_relative_to_output_folder
    mkpath(dirname(path))
    return path
end