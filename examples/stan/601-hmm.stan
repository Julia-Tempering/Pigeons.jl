data {
  int<lower=1> N;
  vector[N] observations;
}

parameters {
  real log_sigma_transition;
  vector[N] latents;
}

transformed parameters {
  real<lower=0> sigma_transition = exp(log_sigma_transition);
}

model {
  log_sigma_transition ~ normal(1,1);
  
  latents[1] ~ normal(2,0.5);
  observations[1] ~ normal(latents[1],1);
  
  for (t in 2:N) {
    latents[t] ~ normal(latents[t-1], sigma_transition);
    observations[t] ~ normal(latents[t],1);
  }
}