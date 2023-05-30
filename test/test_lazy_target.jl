struct MyTargetFlag end 
import Pigeons.instantiate_target
Pigeons.instantiate_target(flag::MyTargetFlag) = toy_mvn_target(1)

@testset "LazyTarget" begin
    pigeons(target = Pigeons.LazyTarget(MyTargetFlag()))
end