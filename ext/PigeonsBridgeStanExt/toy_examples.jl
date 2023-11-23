stan_example_path(name) =
    dirname(dirname(pathof(Pigeons))) * "/examples/stan/$name"



Pigeons.toy_stan_target(dim::Int, precision = 10.0) =
    StanLogPotential(
        stan_example_path("mvn.stan"),
        Pigeons.json(; dim, precision)
    )

Pigeons.toy_stan_unid_target(n_trials = 100000, n_successes = ceil(Int, n_trials/2)) =
    StanLogPotential(
        stan_example_path("unid.stan"),
        Pigeons.json(; n_trials, n_successes)
    )

Pigeons.stan_funnel(dim = 9, scale = 2.0) =
    StanLogPotential(
        stan_example_path("funnel.stan"),
        Pigeons.json(; dim, scale)
    )

Pigeons.stan_bernoulli(y = [0,1,0,0,0,0,0,0,0,1]) =
    StanLogPotential(
        stan_example_path("bernoulli.stan"),
        Pigeons.json(; y, N = length(y))
    )

Pigeons.stan_banana(dim = 9, scale=1.0) =
    StanLogPotential(
        stan_example_path("banana.stan"),
        Pigeons.json(; dim, scale)
    )

function Pigeons.stan_mRNA_post_prior_pair()

    ts = [0.0, 0.1960784314, 0.3921568627, 0.5882352941, 0.7843137255, 0.9803921569, 1.1764705882, 1.3725490196, 1.568627451, 1.7647058824, 1.9607843137, 2.1568627451, 2.3529411765, 2.5490196078, 2.7450980392, 2.9411764706, 3.137254902, 3.3333333333, 3.5294117647, 3.7254901961, 3.9215686275, 4.1176470588, 4.3137254902, 4.5098039216, 4.7058823529, 4.9019607843, 5.0980392157, 5.2941176471, 5.4901960784, 5.6862745098, 5.8823529412, 6.0784313725, 6.2745098039, 6.4705882353, 6.6666666667, 6.862745098, 7.0588235294, 7.2549019608, 7.4509803922, 7.6470588235, 7.8431372549, 8.0392156863, 8.2352941176, 8.431372549, 8.6274509804, 8.8235294118, 9.0196078431, 9.2156862745, 9.4117647059, 9.6078431373, 9.8039215686, 10.0]
    ys = [-28.7432056846, -23.4516614434, -18.5388766424, -14.8222586806, -11.5382220299, -8.7488350492, -6.3148674646, -4.4116646219, -2.662417487, -1.2595749967, -0.2138655106, 0.7533834515, 1.4456718098, 2.256403532, 2.5768037788, 3.1629072506, 3.4035924126, 3.620654275, 3.6067766064, 3.9944954682, 3.8681716905, 3.9908347507, 3.8867758383, 3.9279954787, 3.9740235009, 3.8318783863, 3.8858488538, 3.6889274942, 3.667765745, 3.5132268101, 3.5563189655, 3.3140202907, 3.1375782101, 3.1215096119, 3.1411191324, 2.8587949725, 3.051174779, 2.7046377879, 2.8663809275, 2.7185400221, 2.4358115411, 2.3923558532, 2.4510098123, 2.3022021852, 2.213355665, 2.0576801516, 1.895682169, 1.8026728933, 1.9212597875, 1.8111628461, 1.8321635329, 1.754736356]
    N = length(ts)

    model = stan_example_path("mRNA.stan") 
    data = Pigeons.json(; ts, ys, N)
    empty_data = Pigeons.json(; ts = [], ys = [], N = 0)

    return (;
        posterior = StanLogPotential(model, data),
        prior     = StanLogPotential(model, empty_data)
    )
end

# the centered one is the "harder" one, see https://mc-stan.org/users/documentation/case-studies/divergences_and_bias.html
function Pigeons.stan_eight_schools(centered = true)
    stan_path = stan_example_path("eight_schools_" *
                    (centered ?
                        "centered.stan" :
                        "noncentered.stan"))
    data = stan_example_path("eight_schools.json")
    return StanLogPotential(stan_path, data)
end
