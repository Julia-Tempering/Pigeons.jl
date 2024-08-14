
using CSV
using DataFrames
using Turing
using Pigeons
using SequentialSamplingModels
using Downloads
using LinearAlgebra
using Statistics



function data_poly(x, degree=2; orthogonal=false)
    if orthogonal
        z = x .- mean(x)  # Center the data by subtracting its mean
        X = hcat([z .^ deg for deg in 1:degree]...)  # Create the matrix of powers up to 'degree'
        QR = qr(X)  # Perform QR decomposition
        X = Matrix(QR.Q)  # Extract the orthogonal matrix Q
    else
        X = hcat([x .^ deg for deg in 1:degree]...)  # Create the matrix of powers up to 'degree'
    end
    return X
end

@model function model_exgaussian(data; min_rt=minimum(data.rt), isi=nothing)

    # Transform ISI into polynomials
    isi = data_poly(isi, 2; orthogonal=true)

    # Priors for coefficients
    drift_intercept ~ Normal(0, 1)
    drift_isi1 ~ Normal(0, 1)
    drift_isi2 ~ Normal(0, 1)

    σ ~ Normal(0, 1)
    τ ~ Normal(log(0.2), 1)

    for i in 1:length(data)
        drift = drift_intercept
        drift += drift_isi1 * isi[i, 1]
        drift += drift_isi2 * isi[i, 2]
        data[i] ~ ExGaussian(exp(drift), exp(σ), exp(τ))
    end
end


df = CSV.read(Downloads.download("https://raw.githubusercontent.com/RealityBending/DoggoNogo/main/study1/data/data_game.csv"), DataFrame)

fit = model_exgaussian(df.RT, min_rt=minimum(df.RT), isi=df.ISI)
pt = pigeons(target=TuringLogPotential(fit);
    record=[Pigeons.traces],
    n_rounds=5,
    n_chains=10,
    # checkpoint=true,
    multithreaded=true,
    seed=123)