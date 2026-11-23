@testset "Test is_default_env" begin
    @test !Pigeons.is_default_env()
end

@testset "next_exec_folder is unique under concurrent calls" begin
    mktempdir() do dir
        cd(dir) do
            n = 200
            folders = Vector{String}(undef, n)
            @sync for i in 1:n
                Threads.@spawn folders[i] = Pigeons.next_exec_folder()
            end
            @test length(unique(folders)) == n
            @test all(isdir, folders)
        end
    end
end
