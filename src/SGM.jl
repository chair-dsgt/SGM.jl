module SGM

using JuMP
using NormalGames

include("IPG_structures.jl") 
include("IPG_functions.jl")
include("optimizer.jl")
include("initialization.jl")
include("polymatrix_game.jl")
include("solve.jl")


"""
    optimize!(optimizer::SGM.Optimizer, model::IPGModel; enumeration::Bool = false)::Nothing

Run the IPG solution algorithm implemented by `optimizer` on the IPG model `model`.

If `enumeration` is `false`, the optimizer searches for one equilibrium. If `enumeration` is `true`, the optimizer searches for all equilibria. 
In that case, the optimizer must support equilibria enumeration. 

The result is stored in the optimizer and can be retrieved using `get_equilibrium`.
"""
function optimize!(optimizer::Optimizer, model::IPGModel; enumeration::Bool = false)::Nothing
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
    sampled_game = PolymatrixSampledGame(model, sampled_strategies)

    ### Step 2: Solve sampled game

    ### Step 3: Termination (deviation)

    ### Step 4: Generation of next sampled game



    return nothing
end

end