### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# ╔═╡ 8ff27bee-c6e5-48c1-9a4c-1b999674f6b4
# ╠═╡ show_logs = false
begin
	import Pkg
    Pkg.activate()

	using PlutoUI
    using Plots
	using Statistics
	using Revise
	plotly()
	
	Pkg.activate(".")
	using Pigeons 
	
end

# ╔═╡ cee9aed2-766f-4338-8599-666496eb1b47
html"""<style>
main {
    max-width: 1000px;
}
"""

# ╔═╡ 36158fb4-4f50-44f1-beac-7a5c31de1171
TableOfContents()

# ╔═╡ ecb0601d-118c-432e-be58-7742cbff72e1
md"""
# Pigeons/MPI demo
"""

# ╔═╡ 69d82909-8e96-484e-8740-96d15ea93915
Pigeons.queue_ncpus_free()

# ╔═╡ 13c7307f-3556-4241-af19-2391dbbdfe08
result = pigeons(;
	target = Pigeons.blang_sitka(), 
	recorder_builders = [index_process; Pigeons.default_recorder_builders()], 
	n_rounds = 5, 
	n_chains = 50, 
	checkpoint = true,
	on = MPI(n_mpi_processes = 50))

# ╔═╡ 22a2654a-9a8d-4608-84b3-e7a01650dea9
watch(result, last_n_lines = 100) 

# ╔═╡ e517db71-ac29-4604-8649-540201d9aa27
pt = load(result)

# ╔═╡ 1072f8e9-922b-46e4-8f45-ea8280872cb6
md"""
## Index process
"""

# ╔═╡ ee5aeb5e-3271-4787-9994-1896afab9b48
plot(pt.reduced_recorders.index_process)

# ╔═╡ c51f76b9-964b-46c4-8ab3-d58a71d77036
md"""
## Communication barrier
"""

# ╔═╡ a35522ec-1487-4d89-bd4f-a1fb180fbd5b
plot(pt.shared.tempering.communication_barriers.localbarrier) 

# ╔═╡ Cell order:
# ╟─8ff27bee-c6e5-48c1-9a4c-1b999674f6b4
# ╟─cee9aed2-766f-4338-8599-666496eb1b47
# ╟─36158fb4-4f50-44f1-beac-7a5c31de1171
# ╟─ecb0601d-118c-432e-be58-7742cbff72e1
# ╠═69d82909-8e96-484e-8740-96d15ea93915
# ╠═13c7307f-3556-4241-af19-2391dbbdfe08
# ╠═22a2654a-9a8d-4608-84b3-e7a01650dea9
# ╠═e517db71-ac29-4604-8649-540201d9aa27
# ╟─1072f8e9-922b-46e4-8f45-ea8280872cb6
# ╠═ee5aeb5e-3271-4787-9994-1896afab9b48
# ╟─c51f76b9-964b-46c4-8ab3-d58a71d77036
# ╠═a35522ec-1487-4d89-bd4f-a1fb180fbd5b
