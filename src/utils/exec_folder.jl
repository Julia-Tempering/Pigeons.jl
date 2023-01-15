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
- on windows, one needs admin permission to do symlinks, so fall back to hardlink in that case 
"""
function safelink(target::AbstractString, link::AbstractString)
    relative_to = dirname(link)
    relative_path = relpath(target, relative_to)
    try
        symlink(relative_path, link)
    catch # on windows, need admin to do symlink (!)
        hardlink(abspath(target), abspath(link)) # so then fallback to using hard links
    end
end