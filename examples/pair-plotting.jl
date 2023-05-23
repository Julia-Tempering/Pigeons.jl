using CairoMakie
#using GLMakie
using PairPlots
using Pigeons


function PairPlots.pairplot(pt::PT, chain::Int) 
    samples = Pigeons.get_sample(pt, chain)
    converted = transpose(hcat(samples...))
    return pairplot(converted)
end

function save_open(thing, file = "$(tempname()).pdf") 
    save(file, thing)
    run(`open $file`)
    file
end

