@provides target function toy_stan_target(dim::Int)
    pigeons_path = dirname(dirname(pathof(Pigeons)))
    stan_path = "$pigeons_path/examples/stan/mvn.stan" 
    data = 
        """
        {
            "N" : $dim, 
            "precision" : 1.0
        }
        """
    sm = BridgeStan.StanModel(; stan_file = stan_path, data)
    return StanLogPotential(sm)
    # # TODO: move these files to e.g., /data/
    # bernoulli_stan = "$pigeons_path/test/nikola_temp/bernoulli.stan"
    # bernoulli_data = "$pigeons_path/test/nikola_temp/bernoulli.data.json"
    # smb = BridgeStan.StanModel(stan_file = bernoulli_stan, data = bernoulli_data)
    # return StanLogPotential(smb)
end



function test_stan_allocs(dim)
    lp = toy_stan_target(dim)
    lp = InterpolatedLogPotential(InterpolatingPath(lp, lp), 0.5)
    b = buffers()
    @time g = ADgradient(:dummy, lp, b)
    @time g = ADgradient(:dummy, lp, b)
    x = zeros(dim)
    pt = pigeons(target = toy_stan_target(dim), n_rounds = 1, n_chains = 1, explorer = AutoMALA())
    println("pure grad call")
    @show typeof(g)
    @time LogDensityProblems.logdensity_and_gradient(g, x)
    @time LogDensityProblems.logdensity_and_gradient(g, x)
    # println("even more baremetal")
    # m = lp.model 
    # b = zeros(dim)
    # @time BridgeStan.log_density_gradient!(m, x, b)
    # @time BridgeStan.log_density_gradient!(m, x, b)
    # println("just logdensity")
    # ref = Ref(0.0)
    # err = Ref{Cstring}()
    # @time log_density2(m, x, ref, err)
    # @time log_density2(m, x, ref, err)
    rec = pt.replicas[1].recorders 
    rng = SplittableRandom(1)
    println("automala")
    @time Pigeons.auto_mala!(rng, AutoMALA(exponent_n_refresh = 0.0), g, x, rec, 1, true)
    @time Pigeons.auto_mala!(rng, AutoMALA(exponent_n_refresh = 0.0), g, x, rec, 1, true)
    @time Pigeons.auto_mala!(rng, AutoMALA(), g, x, rec, 1, true)
    @time Pigeons.auto_mala!(rng, AutoMALA(), g, x, rec, 1, true)
    o = ones(dim) 
    v = ones(dim)
    println("leap")
    @time leap_frog!(g, o, x, v, 0.1)
    @time leap_frog!(g, o, x, v, -0.1)
    println("logdiff")
    @time ljdf = log_joint_difference_function(
        g, 
        o,
        x, 
        v, 
        rec
    )
    @time ljdf(0.1)

end

function log_density2(sm::BridgeStan.StanModel, q::Vector{Float64}, lp, err; propto = true, jacobian = true)
    
    
    rc = ccall(
        Libc.Libdl.dlsym(sm.lib, "bs_log_density"),
        Cint,
        (Ptr{BridgeStan.StanModelStruct}, Cint, Cint, Ref{Cdouble}, Ref{Cdouble}, Ref{Cstring}),
        sm.stanmodel,
        propto,
        jacobian,
        q,
        lp,
        err,
    )
    if rc != 0
        BridgeStan.error(BridgeStan.handle_error(sm.lib, err, "log_density"))
    end
    lp[]
end