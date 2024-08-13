mutable struct LogSum{T} <: OnlineStat{Number}
    value::T 
    n::Int 
end

LogSum(T::Type{<:Number} = Float64) = LogSum(-inf(T), 0)

OnlineStatsBase.value(stat::LogSum, args...; kw...) = stat.value 

function OnlineStatsBase._fit!(stat::LogSum, y)
    stat.value = LogExpFunctions.logaddexp(stat.value, y)
    stat.n += 1
end

function OnlineStatsBase._merge!(stat1::LogSum, stat2::LogSum)
    stat1.value = LogExpFunctions.logaddexp(stat1.value, stat2.value)
    stat1.n += stat2.n
end

function Base.empty!(stat::LogSum{T}) where {T}
    stat.value = -inf(T) 
    stat.n = 0
end

