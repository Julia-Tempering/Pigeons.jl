data {
  int<lower=0> number;
  int<lower=0> sum;
}
parameters {
  real<lower=0, upper=1> p1;
  real<lower=0, upper=1> p2;
}

model {
  target += binomial_lpmf(sum | number, p1 * p2);
}

