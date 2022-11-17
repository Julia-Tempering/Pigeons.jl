"""
    acceptanceprobability(newEnergy, newEnergy1, newEnergy2)

Compute acceptance probabilities for communication moves. 
`newEnergy` inputs are lists of numbers. 

# Arguments
- `newenergy`: -log([π_β_0(x^0), π_β_1(x^1), ..., π_β_N(x^N)]) : length N+1
- `newenergy1`: -log([π_β_0(x^1), π_β_1(x^2), ..., π_β_{N-1}(x^N)]) : length N
- `newenergy2`: -log([π_β_1(x^0), π_β_2(x^1), ..., π_β_N(x^{N-1})]) : length N
"""
function acceptanceprobability(newenergy, newenergy1, newenergy2)
    A = newenergy1 .+ newenergy2 .-
    newenergy[1:end-1] .- newenergy[2:end] # Log scale
    return exp.(min.(0, -A))
end

