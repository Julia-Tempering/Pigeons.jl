

mutable struct PT_Iterators
    """
    Index of the PT adaptation *round*, as defined in 
    [Algorithm 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    """
    round::Int 

    """
    Number of (exploration, communication) pairs performed 
    so far, corresponds to ``n`` in 
    [Algorithm 1 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    Round ``i`` typically performs ``2^i`` scans. 
    """
    scan::Int
end

struct PT_Inputs{I}
    inference_problem::I
    rng::SplittableRandom
end

"""
The information provided by adapt! and used to run one round of PT:

$FIELDS
"""
struct PT_Algorithm{R, P, S, E}
    replicas::R
    pair_swapper::P 
    swap_graphs::S 
    explorers::E 
end


function resume_checkpoint(inputs::PT_Inputs, round_folder)
    load_immutables(round_folder_to_immutables(round_folder))
    iterators = load_iterators(round_folder)
    replicas = load_replicas(round_folder)
    reduced_recorders = load_reduced_recorders(round_folder)
    run!(inputs, replicas, reduced_recorders, iterators)
end

function run!(inputs::PT_Inputs)
    replicas = create_replicas(inputs)
    reduced_recorders = reduce_recorders(replicas)
    iterators = PT_Iterators()
    run!(inputs, replicas, reduced_recorders, iterators)
end


"""
$TYPEDSIGNATURES

Perform several PT rounds. 
"""
function run!(inputs::PT_Inputs, replicas, reduced_recorders, iterators)
    while true
        pt_algorithm = adapt(inputs, replicas, reduced_recorders, iterators)   
        reduced_recorders = run_one_round!(inputs, pt_algorithm, iterators)
        replicas = pt_algorithm.replicas 
        checkpoint(inputs, replicas, reduced_recorders)
        if next_round!(inputs, pt_algorithm, iterators) === false
            break
        end
    end
end

"""
$TYPEDSIGNATURES

Perform one PT round. 
"""
function run_one_round!(inputs, pt_algorithm, iterators)
    while true 
        # communication
        swap!(pt_algorithm.pair_swapper, pt_algorithm.replicas, create_swap_graph(pt_algorithm.swap_graphs, pt_algorithm.iterators.scan))
        # exploration 
        @threads for replica in locals(pt_algorithm.replicas)
            explore!(pt_algorithm.explorers, replica)
        end
        if next_scan!(inputs, pt_algorithm, iterators) === false
            break
        end
    end
    return reduce_recorders!(pt_algorithm.replicas)
end

function checkpoint!(pt::PT)
    #= 

    Absolutely essential minimum ingredients for check-pointing:
        - replicas
        - rest could be re-created via inputs + reduce + adapt? 
        - BUT: maybe better post-reduction for space efficiency

    V2: => adapt(pt_inputs, replicas, reduced_recorders)
        - replicas (post-reduction)
        - reduced product

    Need to decide: if resume check point, do we get a 
    new exec folder? 

    Check-pointing should be agnostic to MPI setup.

    =>  Cannot just dump PT object? or custom serializer?
        Separate: Shared_PT + replicas
        Maybe don't even need the shared-pt?
        at least round index - maybe can get from file name


    NOTE: due to file based recorders, much easier to 
    implement across rounds than in the middle of a round.
    
    Maybe need a global round sub-directory structure for 
        clear checkpoint semantics. 

    Use the checkpointing to support re-allocation.
       - NO!! - log_densities could have 
            a nearest_neighbours() function 
            then resample.. but is it worth it, 
            maybe monitor energies, might be better 
            to just add a mini-burn-in after reallocs  
    
    =#
end

function create_pt(inputs::PT_Inputs)
    # probably different enough from adapt?
end

function adapt(inputs, replicas, reduced_recorders, iterators)
    replicas, pair_swapper, swap_graphs, log_potentials = adapt_log_potentials(inputs, replicas, reduced_recorders, iterators)
    explorers = adapt_explorers(inputs, reduced_recorders, log_potentials)
    return PT_Algorithm(replicas, pair_swapper, swap_graphs, explorers)
end
