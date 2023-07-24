function toggle(on = true, except = "reference.md")
    src_path = @__DIR__ * "/src"
    for md_file in readdir(src_path)
        if endswith(md_file, on ? "bu" : "md") && !endswith(md_file, except)
            dest = replace(md_file, on ? ("bu" => "md") : ("md" => "bu")) 
            mv(md_file, dest)
        end
    end
end