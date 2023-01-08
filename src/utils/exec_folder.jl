"""
Return a unique subfolder of 
`results/all/`.  

In some cases it is useful to have a parent 
process (e.g. job submission script) pick 
this unique exec folder for us; to do so, specify 
the unique name in the environment 
variable EXEC_DIR. If the ENV variable 
EXEC_DIR is defined, 
this function will return its contents, and then 
clear the value of that key to ensure subsequent 
calls to `next_exec_folder()` preserve its contract.

Either way, this function will also make sure the 
unique folder and its parents are created. 
It will also create a soft symlink to it 
called `results/latest``
"""
function next_exec_folder()
    result = if haskey(ENV, "EXEC_DIR") && !used_env[]
        pop!(ENV, "EXEC_DIR")
    else
        formatted_time = Dates.format(now(), dateformat"yyyy-mm-dd-HH-MM-SS")
        "results/all/$formatted_time-$(randstring(8))"
    end
    mkpath(result)
    _ensure_symlinked(result)
    return result
end

function pop!(dict::Dict, key)
    result = dict[key]
    delete!(dict, key)
    return result 
end

"""
Create a subfolder of the [`exec_folder()`](@ref).
"""
exec_subfolder(relative_path) = mkpath(exec_folder() / relative_path)

function _ensure_symlinked(exec)
    rm("results/latest", force = true)
    symlink_with_relative_paths(exec, "results/latest")
end

function symlink_with_relative_paths(target::AbstractString, link::AbstractString)
    relative_to = dirname(link)
    relative_path = relpath(target, relative_to)
    symlink(relative_path, link)
end