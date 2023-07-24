data {
  int<lower=0> n_trials;
  int<lower=0> n_successes;
}
parameters {
  real<lower=0, upper=1> p1;
  real<lower=0, upper=1> p2;
}

model {
  target += binomial_lpmf(n_successes | n_trials, p1 * p2);
}

