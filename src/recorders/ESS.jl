mutable struct ESS{T} <: OnlineStat{Number}
    round_size::Int 
    mean_estimate::T 
    sd_estimate::T 

end



