"""
Return a unique subfolder of 
`results/all/`, making sure the 
unique folder and its parents are created. 
It will also create a soft symlink to it 
called `results/latest``
"""
function next_exec_folder()
    formatted_time = Dates.format(now(), dateformat"yyyy-mm-dd-HH-MM-SS")
    result = abspath("results/all/$formatted_time-$(randstring(8))")
    mkpath(result)
    _ensure_symlinked(result)
    return result
end

function _ensure_symlinked(exec)
    rm("results/latest", force = true)
    safelink(exec, "results/latest")
end

"""
$SIGNATURES 

Work around two issues with symlink():
- naively calling symlink() when there are relative paths leads to broken links
- on windows, one needs admin permission to do symlinks, so print a helpful error message in that case
"""
function safelink(target::AbstractString, link::AbstractString)
    relative_to = dirname(link)
    relative_path = relpath(target, relative_to)
    try
        symlink(relative_path, link)
    catch e # on windows, need admin to do symlink (!)
        @warn   """
                Could not create symlink($relative_path, $link)
                    If you are running windows, this is a known issue, 
                    you will need to run under admin permission, see: 
                    https://discourse.julialang.org/t/symlink-can-not-create-hardlink-in-windows10/75702
                    For now, skipping symlinks, this may affect some features 
                    such as loading checkpoints. 
                Details: 
                $e
                """ maxlog=1
    end
end
