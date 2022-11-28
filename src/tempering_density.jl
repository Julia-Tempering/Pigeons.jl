




"""
    potential(d::TemperingDensity, x, η)

Computes the potential of the tempering density i.e., returns

    Vᵣ(x)*η[1] + Vₜ(x)η[2]

where Vᵣ(x) is the reference density and Vₜ(x) is the target density.

# Notes

The potential is defined at the negative log-density (potentially unnormalized):
    V(x) = -log -π(x).

The coefficients η are related to the schedule or temperature of each ladder. For linear
paths we typically have

    Vᵣ(x)(1-β) + Vₜ(x)β

so that η[2] = β and η[2] = (1-β), where β is the *inverse temperature* of the replica.
"""
function potential(d::TemperingDensity, x, η)
    t = target(d)
    r = reference(d)

    η[1] == 1 && return r(x)
    η[2] == 1 && return t(x)
    return r(x)*η[1] + t(x)*η[2]
end


struct TemperingLog{R,L,G,N,RT,RTR,AR}
    rejections::R
    local_barriers::L
    global_barriers::G
    norm_constant::N
    roundtrips::RT
    roundtriprates::RTR
    chain_acc_rates::AR
end

function initialize_log(::SerialScheme, nref, maxround, N, resolution)
    rejections      = map(zeros(N, maxround + 1), 1:nref)
    local_barriers  = map(zeros(resolution, maxround + 1), 1:nref)
    global_barriers = map(zeros(maxround + 1), 1:nref)
    norm_constant   = map(zeros(maxround + 1), 1:nref)
    roundtrips      = map(zeros(maxround + 1), 1:nref)
    roundtriprates   = map(zeros(maxround+1), 1:nref)
    chain_acc_rates = map(zeros(N+1, maxround+1), 1:nref)

    return TemperingLog(
                rejections,
                local_barriers, global_barriers,
                norm_constant,
                roundtrips, roundtriprates,
                chain_acc_rates
                )
end


function initialize_index(::SerialScheme, nref, maxround, N, resolution)
