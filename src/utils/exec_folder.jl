"""
Return a folder which is unique to this execution (process). 
By default, the directory is a subfolder of 
results/all/[unique_name] where the unique_name is 
based on the current time 
and the default random number generator. 

In some cases it is useful to have a parent 
process (e.g. job submission script) pick 
this unique exec folder for us; to do so, specify 
the unique name in the environment 
variable EXEC_DIR. If the ENV variable 
EXEC_DIR is defined, 
this function will return its contents.

Either way, this function will also make sure the 
unique folder and its parents are created. 
It will also create a soft symlink to it 
called `results/latest``
"""
function exec_folder()
    if exec_dir[] === nothing
        next_exec_folder()
    end
    return exec_dir[]
end
const exec_dir = Ref{Union{Nothing,String}}(nothing)
const used_env = Ref(false)

"""
Force the creation of a new global exec_dir. 
"""
function next_exec_folder()
    exec_dir[] = if haskey(ENV, "EXEC_DIR") && !used_env[]
        used_env[] = true
        ENV["EXEC_DIR"]
    else
        formatted_time = Dates.format(now(), dateformat"yyyy-mm-dd-HH-MM-SS")
        "results/all/$formatted_time-$(randstring(8))"
    end
    mkpath(exec_dir[])
    _ensure_symlinked(exec_dir[])
    return exec_dir[]
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