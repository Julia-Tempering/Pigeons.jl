functions {
    // more accurate computation of exp(a)-exp(b), inspired by LSE
    // uses the fact that expm1(x) does not underflow for x<<<0
    // (see e.g. https://en.cppreference.com/w/c/numeric/math/expm1),
    // whereas exp does (https://en.cppreference.com/w/c/numeric/math/exp)
    // main identity
    //     exp(a) - exp(b) = exp(max(a,b))[exp(a-max(a,b))-exp(b-max(a,b))] 
    //     = 1{a>b}exp(a)[1-exp(b-a)] + 1{a<b}exp(b)[exp(a-b)-1]
    //     = -1{a>b}exp(a)expm1(b-a) + 1{a<b}exp(b)expm1(a-b)
    real exp_a_minus_exp_b(real a, real b){
        return a > b ? -exp(a)*expm1(b-a) : exp(b)*expm1(a-b);
    }

    // compute mean for the Likelihood
    //     mu(t) = [km0/(delta-beta)][exp(-beta(t-t0)) - exp(-delta(t-t0))]
    //           = [km0/(delta-beta)] * exp_a_minus_exp_b(-beta(t-t0), -delta(t-t0))
    // if delta ~ beta,
    //     exp(-beta(t-t0)) - exp(-delta(t-t0)) ~ (t-t0)(delta-beta)
    // so
    //     mu(t) = km0(t-t0)
    real get_mu(real tmt0, real km0, real beta, real delta){
        if (tmt0 <= 0.0){
            return 0.0; // must force mu=0 when t<t0 (reaction has not started yet): https://github.com/ICB-DCM/PESTO/blob/3949f150108a051ec0e627c467644290061fc494/examples/mRNA_transfection/logLikelihoodT.m#L69
        }
        real dmb = delta-beta;
        return km0 * ( abs(dmb) < machine_precision() ? tmt0 : exp_a_minus_exp_b(-beta*tmt0, -delta*tmt0)/dmb );
    }
}
data {
    int <lower=0> N; // number of observations
    array[N] real<lower=0> ts; // time of the observation
    array[N] real ys; // observed value
}
parameters {
    real<lower=-2,upper=1> lt0;
    real<lower=-5,upper=5> lkm0;
    real<lower=-5,upper=5> lbeta;
    real<lower=-5,upper=5> ldelta;
    real<lower=-2,upper=2> lsigma;
}
transformed parameters{
    // real t0, km0, beta, delta, sigma;
    real t0    = pow(10, lt0);
    real km0   = pow(10, lkm0);
    real beta  = pow(10, lbeta);
    real delta = pow(10, ldelta);
    real sigma = pow(10, lsigma);
}
model {
    // Priors are all uniform so they are implicit
    // Likelihood:
    //     y_i|params ~indep N(mu_i, sigma)
    // with
    //     mu_i = get_mu(tmt0, km0, beta, delta, sigma)
    for (i in 1:N) {
        ys[i] ~ normal(get_mu(ts[i] - t0, km0, beta, delta), sigma);
    }
}
