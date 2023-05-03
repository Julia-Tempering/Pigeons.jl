data {
  int<lower=0> N;
  array[N] int<lower=0, upper=1> y;
}
parameters {
  real<lower=0,upper=1> theta;
}
transformed parameters {
  real logit_theta = logit(theta);
}
model {
  theta ~ beta(1, 1);
  y ~ bernoulli(theta);
}
generated quantities {
  int y_sim = bernoulli_rng(theta);
}
