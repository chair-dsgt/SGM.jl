module SGM

using JuMP
using NormalGames
using Random

include("IPG/IPG_structures.jl") 
include("IPG/IPG_functions.jl")
include("optimizer.jl")
include("initialization.jl")
include("Polymatrix/polymatrix_game.jl")
include("Polymatrix/solve.jl")
include("player_order.jl")


"""
    optimize!(optimizer::SGM.Optimizer, model::IPGModel; enumeration::Bool = false)::Nothing

Run the IPG solution algorithm implemented by `optimizer` on the IPG model `model`.

If `enumeration` is `false`, the optimizer searches for one equilibrium. If `enumeration` is `true`, the optimizer searches for all equilibria. 
In that case, the optimizer must support equilibria enumeration. 

The result is stored in the optimizer and can be retrieved using `get_equilibrium`.
"""
function optimize!(optimizer::Optimizer, model::IPGModel; 
                   enumeration::Bool = false, max_iter::Integer=100, dev_tol::Float64=1e-3)::Nothing
    if enumeration
        throw(ArgumentError("SGM.Optimizer does not support equilibria enumeration.")) 
    end

    optimizer.termination_status = INTERRUPTED
    optimizer.equilibrium = nothing
    players = model.players
    num_players = length(players)

    # SGM algorithm:

    ### Step 1: Initialization of sampled game
    sampled_strategies = initialize_strategies(players, num_players, optimizer.best_response_optimizer)
    sampled_game = PolymatrixSampledGame(model, sampled_strategies)

    candidate_equilibria = Vector{Profile}()
    payoff_improvements = Vector{Tuple{Int,Float64}}()
    for iter in 1:max_iter
        ### Step 2: Solve sampled game
        candidate_equilibrium = solve(sampled_game, optimizer_factory)
        push!(candidate_equilibria, candidate_equilibrium)

        ### Step 3: Termination (deviation)


        ### Step 4: Generation of next sampled game
    end


    return nothing
end

end