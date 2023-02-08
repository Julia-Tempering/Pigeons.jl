### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 8ff27bee-c6e5-48c1-9a4c-1b999674f6b4
# ╠═╡ show_logs = false
begin
	println("asdf")
	import Pkg
    Pkg.activate()

	using PlutoUI
    using Plots
	using Statistics
	using Revise
	
	Pkg.activate(".")
	Pkg.resolve()
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
# Pigeons demo
"""

# ╔═╡ e1b58e13-cac8-468d-8402-0a23d443e47d
@bind n_chains Slider(5:50)

# ╔═╡ d90ff8fd-b336-4637-8f14-1f8334d9f1ac
@bind dim Slider(5:50)

# ╔═╡ 13c7307f-3556-4241-af19-2391dbbdfe08
result = pigeons(;
	target = toy_mvn_target(1), 
	recorder_builders = [index_process; Pigeons.default_recorder_builders()], 
	n_rounds = 7, 
	n_chains = 20, 
	on = MPI(n_mpi_processes = 20))

# ╔═╡ 603df658-a186-458b-b5c3-42b63832204a


# ╔═╡ 22a2654a-9a8d-4608-84b3-e7a01650dea9
watch(result, last_n_lines = 100)

# ╔═╡ 0bc71aeb-1c2f-45a8-9af4-8de3004aa930


# ╔═╡ c517745d-c3f7-4c5e-9e99-0c90aaa95b7f


# ╔═╡ 73b6565f-cfd5-4806-8cb1-6b5714ec6fe3


# ╔═╡ 00a4fdc6-eed0-4dc1-bfa5-9f2b8fa9034f


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
# ╠═cee9aed2-766f-4338-8599-666496eb1b47
# ╠═36158fb4-4f50-44f1-beac-7a5c31de1171
# ╟─ecb0601d-118c-432e-be58-7742cbff72e1
# ╠═e1b58e13-cac8-468d-8402-0a23d443e47d
# ╠═d90ff8fd-b336-4637-8f14-1f8334d9f1ac
# ╠═13c7307f-3556-4241-af19-2391dbbdfe08
# ╠═603df658-a186-458b-b5c3-42b63832204a
# ╠═22a2654a-9a8d-4608-84b3-e7a01650dea9
# ╠═0bc71aeb-1c2f-45a8-9af4-8de3004aa930
# ╠═c517745d-c3f7-4c5e-9e99-0c90aaa95b7f
# ╠═73b6565f-cfd5-4806-8cb1-6b5714ec6fe3
# ╠═00a4fdc6-eed0-4dc1-bfa5-9f2b8fa9034f
# ╟─1072f8e9-922b-46e4-8f45-ea8280872cb6
# ╠═ee5aeb5e-3271-4787-9994-1896afab9b48
# ╟─c51f76b9-964b-46c4-8ab3-d58a71d77036
# ╠═a35522ec-1487-4d89-bd4f-a1fb180fbd5b
