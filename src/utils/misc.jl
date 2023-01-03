"""
    winsorized_mean(x; α)

Compute the winsorized mean from an input `x`, which is assumed to be a vector of vectors. 
`α` denotes the percentage of observations to winsorize at the bottom and the top 
so that we use 1 - 2α observations and winsorize the rest.
"""
function winsorized_mean(x; α=0.1)
    dim_x = length(x[1])
    out = Vector{Float64}(undef, dim_x)
    n = length(x)
    n_lower = convert(Int64, floor(α*n))

    for j in 1:dim_x
        y = sort(map((i) -> x[i][j], 1:n))
        out[j] = 1/n * (n_lower * y[n_lower] + sum(y[(n_lower + 1):(n - n_lower)]) + n_lower * y[n - n_lower + 1])
    end

    return out
end


"""
    winsorized_std(x; α)

Compute the winsorized standard deviation. The parameters are the same 
as those for `winsorized_mean()`.
"""
function winsorized_std(x; α=0.1)
    dim_x = length(x[1])
    out = Vector{Float64}(undef, dim_x)
    n = length(x)
    n_lower = convert(Int64, floor(α*n))

    for j in 1:dim_x
        y = map((i) -> x[i][j], 1:n)
        y2 = y .^ 2
        y2 = sort(y2)
        y2_mean = 1/n * (n_lower * y2[n_lower] + sum(y2[(n_lower + 1):(n - n_lower)]) + n_lower * y2[n - n_lower + 1]) # winsorized estimate of E[Y[j]^2]
        out[j] = sqrt(y2_mean - winsorized_mean(y; α=α)[1]^2)
    end
    
    return out
end


"""
    lognormalizingconstant(energies, schedule)

Compute an estimate of the log normalizing constant given a vector of 
`energies` and the corresponding annealing `schedule`.
"""
function lognormalizingconstant(energies, schedule)
    n, N = size(energies)
    Δβ = schedule[2:end] .- schedule[1:end-1]
    μ = mean(energies, dims = 1)[2:end]
    sum(Δβ.*μ)
end


"""
    computeetas(ϕ, β)

Compute the `etas` matrix given `ϕ`, which is an Array(K - 1, 2) containing 
knot parameters, and `β`, a vector of `N`+1 schedules. For linear paths, 
the function returns an (N+1)x2 matrix with entries 1-β in the first column 
and β in the second column. (This function is useful for those wishing to consider
non-linear paths. However, full support is provided only for linear paths at 
the moment.) 
"""
function computeetas(ϕ, β)
    if ϕ != [0.5 0.5]
        error("ϕ must be [0.5 0.5]")
    end

    out = zeros(length(β), 2)
    for i in 1:length(β)
        out[i, 1] = 1.0 - β[i]
        out[i, 2] = β[i]
    end

    return out
end

"""
$TYPEDSIGNATURES

From one splittable random object, one can conceptualize an infinite list of splittable random objects. 
Return a slice from this infinite list.
"""
function split_slice(
        slice::UnitRange, # NB: assumes slice is contiguous, i.e. don't duck-type UnitRate
        rng)
    @assert slice[1] ≥ 1
    # todo: could be done more efficiently with a tree but low priority
    # get rid of stuff at left of slice
    n_to_burn = slice[1] - 1
    [split(rng) for i in 1:n_to_burn]
    # get the slice of random objects by splitting:
    return [split(rng) for i in slice]
end

macro abstract() quote error("Attempted to call an abstract function.") end end

function mpi_test(n_processes::Int, test_file::String; options = [])
    project_folder = dirname(Base.current_project())
    mpiexec() do exe
        run(`$exe -n $n_processes $(Base.julia_cmd()) --project=$project_folder $project_folder/test/$test_file $options`)
    end
end

/(s1::AbstractString, s2::AbstractString) = s1 * "/" * s2

# Compute w*x, but if w==0.0, do not evaluate x and just return 0.0
macro weighted(w, x) 
    :($(esc(w)) == 0.0 ? 0.0 : $(esc(w)) * $(esc(x)))
end

"""
$TYPEDSIGNATURES

Subset the tuple to the given key_subset.
Check all keys in key_subset are in keys(tuple).
"""
function slice_tuple(tuple, key_subset)
    valids = keys(tuple)
    for key in key_subset
        @assert key in valids
    end
    return NamedTuple(
        filter(
            key_value_pair -> key_value_pair.first in key_subset, 
            collect(pairs(tuple))
        )
    )
end

# helpers to automate documention generation

mutable struct InformalInterfaceSpec
    name::Symbol
    declaration::Expr
    InformalInterfaceSpec(name, declaration) = new(name, declaration)
end

function declarations(i::InformalInterfaceSpec) 
    @capture(i.declaration, begin methods__ end)
    return methods
end

"""
    @informal name begin ... end

Document an informal interface with provided `name`, and functions 
specified in a `begin .. end` block. 

`@informal` will spit back the contents of the `begin .. end` block so 
this macro can be essentially ignored at first read. 

When building documentation, this allows us to use the 
function [`informal_doc()`](@ref) to automatically document the 
informal interface.
"""
macro informal(name::Symbol, arg::Expr)
    return quote
        $(esc(name)) = begin
            $(esc(arg));
            InformalInterfaceSpec(:($$(Meta.quot(name))), :($$(Meta.quot(arg)))) 
        end
    end
end

const providers_dict = Dict{String, Set{Expr}}() # we would want Pair{Module,Symbol} but Module seems to have buggy hash/equality behaviour
function add_provider(key, value)
    if !haskey(providers_dict, key)
        providers_dict[key] = Set{Expr}()
    end
    push!(providers_dict[key], value)
end
macro provides(name::Symbol, arg::Expr)
    key = "$__module__.$name"
    add_provider(key, arg)
    return quote 
        $(esc(arg))
    end
end

resolve(name::Symbol, mod) = mod.eval(:($name))

function informal_interfaces(mod)
    return names(mod; all = true) |> 
        t -> filter(name -> typeof(resolve(name, mod)) == InformalInterfaceSpec, t) |>
        f -> map(name -> (name, resolve(name, mod)), f)
end

const informal_file_name = ".interfaces"

"""
$(TYPEDSIGNATURES)
Generate informal interface documentation, e.g.: 
```
makedocs(;
    ...
    pages=[
        "Home" => "index.md", 
        "Interfaces" => informal_doc(@__DIR__, MyModuleName),
        ...
    ]
)
```
"""
function informal_doc(doc_dir, mod::Module)
    head = """
    Descriptions of *informal interfaces* (see [Pigeons.@informal](reference.html#Pigeons.@informal-Tuple{Symbol,%20Expr}) to see how this page 
    was generated).

    ---
    """
    contents = join([informal_doc(n, i, mod) for (n, i) in informal_interfaces(mod)], "\n\n---\n\n")
    f = "$doc_dir/src/$informal_file_name.md"
    write(f, head * contents)
    return "$informal_file_name.md"
end

function get_doc(name::Symbol, mod::Module)
    expr = :(@doc $mod.$name)
    return eval(expr)
end

informal_section(name) = "`$name`"
function informal_link(name) 
    section_link = replace(informal_section(name), " " => "-", "`" => "")
    return "$informal_file_name.html#$section_link"
end

"""
$TYPEDSIGNATURES

Provides a `Set{Expr}` containing all the providers of the 
given name in the given module. 
"""
function providers(mod::Module, name::Symbol)
    key = "$mod.$name"
    return haskey(providers_dict, key) ? providers[key] : Set{Expr}()
end

function informal_doc(name::Symbol, interface::InformalInterfaceSpec, mod::Module)
    current_providers = providers(mod, name)
    return """
    ## $(informal_section(name))

    #### Description

    ```@docs
    $mod.$name
    ```

    $(isempty(declarations(interface)) ? "" : "#### Contract")

    $(join([informal_doc(e, mod) for e in declarations(interface)]))

    $(isempty(current_providers) ? "" : "#### Examples of functions providing instances of this interface")

    $(join(Set([informal_doc(e, mod) for e in current_providers])))

    """
end

function informal_doc(declaration::Expr, mod::Module)
    split = split_documented(declaration)
    return """
    - [`$mod.$(split[:name])()`](@ref)

    """
end

function split_documented(declaration::Expr)
    expression = declaration.head == :macrocall ? declaration.args[4] : declaration
    return MacroTools.splitdef(expression)
end
