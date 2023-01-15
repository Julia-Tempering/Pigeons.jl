using Pigeons

# model = Pigeons.flip_model()
model = Pigeons.flip_model_unidentifiable()

pigeons(target = Pigeons.TuringLogPotential(model)) 