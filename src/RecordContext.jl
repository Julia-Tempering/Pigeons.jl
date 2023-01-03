
remove this.. using globals now

"""
Passed to [`record!()`](@ref) to provide the following 
context to the [`recorder`](@ref):

$FIELDS
"""
mutable struct RecordContext
    """Current round and scan."""
    iterators::PT_Iterators

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