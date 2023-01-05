"""
Generate a folder unique to this execution. 
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
        exec_dir[] = haskey(ENV, "EXEC_DIR") ? 
            ENV["EXEC_DIR"] :
            "results/all/$(DateTime(now()))-$(randstring(8))"
        mkpath(exec_dir[])
        _ensure_symlinked()
    end
    return exec_dir[]
end
const exec_dir = Ref{Union{Nothing,String}}(nothing)

function _ensure_symlinked()
    rm("results/latest", force = true)
    symlink(exec_dir[], "results/latest", dir_target = true)
end