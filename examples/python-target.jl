include("../test/activate_test_env.jl")
using PythonCall

###############################################################################
# Pigeons for Bayesian inference for parameters of ODE coded in Python (with Numba)
# Example and data taken from
# https://www.pymc.io/projects/examples/en/latest/ode_models/ODE_Lotka_Volterra_multiple_ways.html
###############################################################################

# # install packages (run just once)
# using CondaPkg 
# CondaPkg.add("numpy")
# CondaPkg.add("pandas")
# CondaPkg.add("scipy")
# CondaPkg.add("numba", channel="numba")

# imports and definitions
py_make_fun_str = """

# import modules
import numpy as np
import pandas as pd
from numba import njit
from scipy.integrate import odeint

# create the data
data = pd.DataFrame(dict(
    year = np.arange(1900., 1921., 1),
    lynx = np.array([4.0, 6.1, 9.8, 35.2, 59.4, 41.7, 19.0, 13.0, 8.3, 9.1, 7.4,
                8.0, 12.3, 19.5, 45.7, 51.1, 29.7, 15.8, 9.7, 10.1, 8.6]),
    hare = np.array([30.0, 47.2, 70.2, 77.4, 36.3, 20.6, 18.1, 21.4, 22.0, 25.4, 
                 27.1, 40.3, 57.0, 76.6, 52.3, 19.5, 11.2, 7.6, 14.6, 16.2, 24.7])))

# define the right hand side of the ODE equations in the Scipy odeint signature
@njit
def rhs(X, t, theta):
    # unpack parameters
    x, y = X
    alpha, beta, gamma, delta, xt0, yt0 = theta
    # equations
    dx_dt = alpha * x - beta * x * y
    dy_dt = -gamma * y + delta * x * y
    return [dx_dt, dy_dt]

# function that calculates residuals based on a given theta
def ode_model_resid(theta):
    return (
        data[["hare", "lynx"]] - odeint(func=rhs, y0=theta[-2:], t=data.year, args=(theta,))
    ).values.flatten()

"""
pyexec(py_make_fun_str, Main)
jl_ode_model_resid(t) = pyeval(Vector{Float64},"ode_model_resid(theta)", Main, (theta=t,))
const theta_init = [0.52, 0.026, 0.84, 0.026, 34.0, 5.9]
@assert jl_ode_model_resid(theta_init) isa Vector
@time jl_ode_model_resid(theta_init) # 9k allocs!!

# construct the necessary pigeons inputs
reference_lp = DistributionLogPotential(
    product_distribution(
        TruncatedNormal(theta_init[1],0.1 ,0.,Inf),
        TruncatedNormal(theta_init[2],0.01,0.,Inf),
        TruncatedNormal(theta_init[3],0.1 ,0.,Inf),
        TruncatedNormal(theta_init[4],0.01,0.,Inf),
        TruncatedNormal(theta_init[5],1.0 ,0.,Inf),
        TruncatedNormal(theta_init[6],1.0 ,0.,Inf),
        TruncatedNormal(0.,10.,0.,Inf)
    )
);
struct PyLogPotential{R}
    ref_lp::R
end
function (plp::PyLogPotential)(x)
    prior = plp.ref_lp(x)
    isinf(prior) && return prior
    theta = @view x[begin:(end-1)]
    sigma = last(x)
    errs  = pyeval(Vector{Float64},"ode_model_resid(theta)", Main, (theta=theta,))
    prior + loglikelihood(Normal(0.,sigma), errs)
end
Pigeons.initialization(::PyLogPotential, ::AbstractRNG, ::Int) = [theta_init;3.0]

# run pigeons
# incredibly slow due to the huge number of allocs per likelihood eval
pt = pigeons(
    target = PyLogPotential(reference_lp),
    reference = reference_lp, 
    record = record_online()
)
