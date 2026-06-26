module SGM

using JuMP

include("IPG_structures.jl") 
include("IPG_functions.jl")
include("optimizer.jl")
include("initialization.jl")
include("polymatrix_game.jl")



function optimize!(optimizer::Optimizer, model::IPGModel; enumeration::Bool = false)
    if enumeration
        throw(ArgumentError("SGM.Optimizer does not support equilibria enumeration.")) 
    end

    optimizer.termination_status = SOLVE_NOT_CALLED
    optimizer.equilibrium = nothing
    players = model.players
    num_players = length(players)

    # SGM algorithm:

    ### Step 1: Initialization of sampled game
    sampled_strategies = initialize_strategies(players, num_players, optimizer.best_response_optimizer)

    ### Step 2: Solve sampled game

    ### Step 3: Termination (deviation)

    ### Step 4: Generation of next sampled game



    return nothing
end

end