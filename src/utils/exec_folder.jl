"""
Return a unique subfolder of 
`results/all/`, taking care of creating the 
directories in that path.  

It will also create a soft symlink to the 
returned folder  
called `results/latest`.
"""
function next_exec_folder()
    formatted_time = Dates.format(now(), dateformat"yyyy-mm-dd-HH-MM-SS")
    result = "results/all/$formatted_time-$(randstring(8))"
    mkpath(result)
    _symlink_exec_folder(result)
    return result
end

function _symlink_exec_folder(exec)
    rm("results/latest", force = true)
    symlink_with_relative_paths(exec, "results/latest")
end

function symlink_with_relative_paths(target::AbstractString, link::AbstractString)
    relative_to = dirname(link)
    relative_path = relpath(target, relative_to)
    symlink(relative_path, link)
end