data {
    int<lower=1> dim;
    real<lower=0> scale;
}
parameters {
  real y;
  vector[dim] x;
}
model {
  y ~ normal(0, 3);
  x ~ normal(0, exp(y/scale));
}
