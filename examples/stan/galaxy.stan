// Adapted from https://mc-stan.org/docs/stan-users-guide/summing-out-the-responsibility-parameter.html
//   with priors based on the parameterization of Bettina et al., 2022
data {
  int<lower=1> K;          // number of mixture components
  int<lower=1> N;          // number of data points  

  vector[K] alpha;         // Dirichlet concentration

  real b_0;                // component mean prior parameters     
  real<lower=0> B_0;

  real<lower=0> c_0;       // component inverse variance prior parameters    
  real<lower=0> C_0;

  array[N] real y;         // observations
}
parameters {
  simplex[K] theta;        // mixing proportions

  ordered[K] mu;           // locations of mixture components
  vector<lower=0>[K] inv_sigma2;  // scales of mixture components
}
model {
  theta ~ dirichlet(alpha);
  vector[K] log_theta = log(theta);  // cache log calculation
  inv_sigma2 ~ gamma(c_0, C_0);
  mu ~ normal(b_0, sqrt(B_0));
  for (n in 1:N) {
    vector[K] lps = log_theta;
    for (k in 1:K) {
      lps[k] += normal_lpdf(y[n] | mu[k], sqrt(1/inv_sigma2[k]));
    }
    target += log_sum_exp(lps);
  }
}