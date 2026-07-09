module SGM

using JuMP
using NormalGames
using Random
using LinearAlgebra
using Gurobi
using Juniper
using Ipopt
using PiecewiseLinApprox
using PiecewiseLinearOpt

include("IPG/IPG_structures.jl") 
include("IPG/IPG_functions.jl")
include("optimizer.jl")
include("initialization.jl")
include("SampledGames/Polymatrix/polymatrix_game.jl")
include("SampledGames/Polymatrix/solve.jl")
include("SampledGames/Normal_form/normal_form_game.jl")
include("SampledGames/Normal_form/MultiPlayer_Nash_Algorithms.jl")
include("SampledGames/Normal_form/solve.jl")
include("SampledGames/sampled_game_initialization.jl")
include("player_order.jl")
include("deviation.jl")



"""
    search!(optimizer::SGM.Optimizer, model::IPGModel; enumeration::Bool = false)::Nothing

Run the IPG solution algorithm implemented by `optimizer` on the IPG model `model`.

If `enumeration` is `false`, the optimizer searches for one equilibrium. If `enumeration` is `true`, the optimizer searches for all equilibria. 
In that case, the optimizer must support equilibria enumeration. 

The result is stored in the optimizer and can be retrieved using `get_equilibrium`.
"""
function search!(optimizer::Optimizer, model::IPGModel; 
                   enumeration::Bool = false, max_iter::Integer=100, dev_tol::Float64=1e-3)::Nothing
    if enumeration
        optimizer.termination_status = INVALID_OPTION
        throw(ArgumentError("SGM.Optimizer does not support equilibria enumeration.")) 
    end

    optimizer.termination_status = INTERRUPTED
    optimizer.equilibrium = nothing
    players = model.players
    num_players = length(players)

    # SGM algorithm:

    ### Step 1: Initialization of sampled game
    sampled_strategies = initialize_strategies(players, num_players, optimizer.best_response_optimizer)
    sampled_game = initialize_sampled_game(model, sampled_strategies)

    candidate_equilibria = Vector{Profile}()
    payoff_improvements = Vector{Tuple{Int,Float64}}()
    for iter in 1:max_iter
        ### Step 2: Solve sampled game
        candidate_equilibrium = solve(sampled_game, optimizer.equilibrium_computation_optimizer)
        push!(candidate_equilibria, candidate_equilibrium)

        player_order = get_player_order(num_players, payoff_improvements)
        ### Step 3: Termination (deviation)
        payoff_improvement, player_id, new_strategy = find_deviation(model, candidate_equilibrium, optimizer.best_response_optimizer, player_order, dev_tol)

        if payoff_improvement <= dev_tol # Equilibrium found
            optimizer.termination_status = EQUILIBRIUM_FOUND
            optimizer.equilibrium = candidate_equilibrium
            break 
        end

        push!(payoff_improvements, (player_id, payoff_improvement))
        ### Step 4: Generation of next sampled game
        push!(sampled_game.strategy_sample[player_id], new_strategy)
        update_sampled_game!(sampled_game, player_id, model)

        if iter == max_iter
            optimizer.termination_status = ITERATION_LIMIT
        end
    end

    return nothing
end
end