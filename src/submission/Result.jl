"""
A link to an execution folder able to 
deserialize type T via a string constructor.
"""
struct Result{T}
    exec_folder::String 
end

"""
$SIGNATURES 

Load the result in memory.
"""
function load(result::Result{T}) where T 
    return T(result.exec_folder)
end
