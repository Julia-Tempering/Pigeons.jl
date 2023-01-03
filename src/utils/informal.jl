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
