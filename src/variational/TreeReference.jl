"""
A Gaussian tree variational reference
"""

#TODO
@kwdef mutable struct TreeReference
    edges
    num_nodes
    first_tuning_round
end

#TODO
@kwdef mutable struct node
    data
    mean
    variance
end


dim(variational::TreeReference) = variational.num_nodes
#TODO
function activate_variational(variational::TreeReference, iterators::Iterators)
end
#TODO
variational_recorder_builders(::TreeReference) = [_transformed_online]



#TODO
function update_reference!(reduced_recorders, variational::TreeReference, state)
end
#TODO
function compute_mutual_info()
end
#TODO
function tree_decomposition()
end
#TODO
function prims_spanning_tree()
end



#TODO
function sample_iid!(variational::TreeReference, replica, shared)
end
#TODO
function (variational::TreeReference)(state)
end
#TODO
function tree_logdensity()
end



# LogDensityProblemsAD implementation (currently only for special case of a singleton variable)
#TODO
LogDensityProblems.logdensity(log_potential::TreeReference, x) =
    tree_logdensity()

#TODO
function LogDensityProblems.dimension(log_potential::TreeReference)
end
#TODO
LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType. log_potential::TreeReference, replica::Replica) =
    BufferedAD(log_potential, replica.recorders.buffers)
#TODO
function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{TreeReference}, x)
end