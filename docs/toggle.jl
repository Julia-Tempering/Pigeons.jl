function toggle(on = true, except = "reference.md")
    src_path = "$(@__DIR__)/src"
    for md_file in readdir(src_path)
        if endswith(md_file, on ? "bu" : "md") && !endswith(md_file, r"reference.md|interfaces.md")
            dest = replace(md_file, on ? ("bu" => "md") : ("md" => "bu")) 
            mv("$src_path/$md_file", "$src_path/$dest")
        end
    end
end