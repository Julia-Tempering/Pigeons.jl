data {
  int<lower=0> dim;
  real<lower=0> precision;
}
parameters {
  vector[dim] x;
}

model {
  for (n in 1:dim) {
    target += -0.5 * precision * x[n] * x[n];
  }
}

