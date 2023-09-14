// n-dimensional banana, as defined sec 3 of https://doi.org/10.1111/sjos.12532
// uses n1 = 2, n2 = dim => total dims = dim + 1
// easier values from eq 50 of https://arxiv.org/abs/2003.03636
//         x ~ N(0, s_a)   // s_a = sqrt(inv(2a)), a = 1/20 (2.5 easier)
// y_{1:d}|x ~ N(x^2, s_b) // s_b = sqrt(inv(2b)), b = 5    (50 easier)
data {
    int<lower=1> dim;
}
transformed data {
    real a, b, s_a, s_b;
    a   = inv(20);
    b   = 5.0;
    s_a = sqrt(inv(2*a));
    s_b = sqrt(inv(2*b));
}
parameters {
    real x;
    vector[dim] y;
}
model {
    x ~ normal(0, s_a);
    y ~ normal(square(x), s_b);
}