#= 
Use `toggle(false)` to change non-essential doc pages in `docs/src/` from `.md` to `.bu`. 
Then when you add a new .md page and run `make.jl` local doc generation will 
be faster. Use `toggle(true)` to move `.bu`'s back to `.md`.
=#
function toggle(on = true, except = "reference.md")
    src_path = "$(@__DIR__)/src"
    for md_file in readdir(src_path)
        if endswith(md_file, on ? "bu" : "md") && !endswith(md_file, r"reference.md|interfaces.md")
            dest = replace(md_file, on ? (".bu" => ".md") : (".md" => ".bu")) 
            mv("$src_path/$md_file", "$src_path/$dest")
        end
    end
end