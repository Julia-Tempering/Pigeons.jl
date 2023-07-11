data {
  int<lower=0> N;
  real<lower=0> precision;
}
parameters {
  vector[N] x;
}

model {
  for (n in 1:N) {
    target += -0.5 * precision * x[n] * x[n];
  }
}

