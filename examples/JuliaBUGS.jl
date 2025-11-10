function incomplete_count_data_model(;tau::Real=4)
    model_def = @bugs("model{
        for (i in 1:n) {
        r[i] ~ dbern(pr[i])
        pr[i] <- ilogit(y[i] * alpha1 + alpha0)
        y[i] ~ dpois(mu)
        }
        mu ~ dgamma(1,1)
        alpha0 ~ dnorm(0, 0.1)
        alpha1 ~ dnorm(0, tau)
        }",false,false
    )
    data = (
        y = [
            6,missing,missing,missing,missing,missing,missing,5,1,missing,1,missing,
            missing,missing,2,missing,missing,0,missing,1,2,1,7,4,6,missing,missing,
            missing,5,missing
            ],
        r = [1,0,0,0,0,0,0,1,1,0,1,0,0,0,1,0,0,1,0,1,1,1,1,1,1,0,0,0,1,0],
        n = 30, tau = tau
    )
    return compile(model_def, data)
end
incomplete_count_data(;kwargs...) = JuliaBUGSPath(incomplete_count_data_model(;kwargs...))
