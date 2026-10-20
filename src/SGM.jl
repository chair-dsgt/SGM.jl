module SGM

using JuMP
using NormalGames
using Random
using LinearAlgebra

import IPG
import IPG: search!, get_equilibrium, get_equilibria, get_termination_status, supports_enumeration

include("time.jl")
include("equilibrium_solver.jl")
include("initialization.jl")
include("SampledGames/Polymatrix/polymatrix_game.jl")
include("SampledGames/Polymatrix/solve.jl")
include("SampledGames/Normal_form/normal_form_game.jl")
include("SampledGames/Normal_form/MultiPlayer_Nash_Algorithms.jl")
include("SampledGames/Normal_form/solve.jl")
include("SampledGames/sampled_game_initialization.jl")
include("player_order.jl")
include("deviation.jl")
include("candidate_solutions.jl")


"""
    search!(equilibrium_solver::SGM.EquilibriumSolver, model::IPG.IPGModel; enumeration::Bool = false, 
                    max_iter::Integer=100, dev_tol::Float64=1e-3, time_limit::Float64=Inf)::Nothing

Run the IPG solution algorithm implemented by `equilibrium_solver` on the IPG model `model`.

If `enumeration` is `false`, the equilibrium solver searches for one equilibrium. If `enumeration` is `true`, the equilibrium solver searches for all equilibria. 
In that case, the equilibrium solver must support equilibria enumeration. 

The result is stored in the equilibrium solver and can be retrieved using `get_equilibrium` or `get_equilibria`.
"""
function search!(equilibrium_solver::EquilibriumSolver, model::IPG.IPGModel; 
    enumeration::Bool = false, max_iter::Integer=100, dev_tol::Float64=1e-3, time_limit::Float64=Inf)::Nothing

    timer = SGMTimer(time_limit)

    try
        equilibrium_solver.termination_status = IPG.INTERRUPTED
        equilibrium_solver.equilibrium = nothing
        equilibrium_solver.equilibria = IPG.Profile[]
        
        if enumeration
            esgm_search!(equilibrium_solver, model, max_iter, dev_tol, timer)
        else
            sgm_search!(equilibrium_solver, model, max_iter, dev_tol, timer)
        end
    
    catch error
        if error isa TimeLimitException
            equilibrium_solver.termination_status = IPG.TIME_LIMIT
            return nothing
        end
        rethrow()
    end
    
    return nothing
end

function sgm_search!(equilibrium_solver::EquilibriumSolver, model::IPG.IPGModel, max_iter::Integer, dev_tol::Float64, timer::SGMTimer)::Nothing   
    players = model.players
    num_players = length(players)
    check_time(timer)
    
    # SGM algorithm:
    
    ### Step 1: Initialization of sampled game
    sampled_strategies = initialize_strategies(players, num_players, equilibrium_solver.best_response_optimizer, timer)
    check_time(timer)
    sampled_game = initialize_sampled_game(model, sampled_strategies, timer)
    check_time(timer)
    
    equilibrium_solver.candidate_equilibria = Vector{IPG.Profile}()
    payoff_improvements = Vector{Tuple{Int,Float64}}()
    for iter in 1:max_iter
        ### Step 2: Solve sampled game
        candidate_equilibrium = solve(sampled_game, timer, equilibrium_solver.sampled_game_optimizer)
        check_time(timer)
        push!(equilibrium_solver.candidate_equilibria, candidate_equilibrium)
    
        player_order = get_player_order(num_players, payoff_improvements)
        check_time(timer)
        ### Step 3: Termination (deviation)
        payoff_improvement, player_id, new_strategy = find_deviation(model, candidate_equilibrium, equilibrium_solver.best_response_optimizer, timer, player_order, dev_tol)
        check_time(timer)
    
        if payoff_improvement <= dev_tol # Equilibrium found
            equilibrium_solver.termination_status = IPG.EQUILIBRIUM_FOUND
            equilibrium_solver.equilibrium = candidate_equilibrium
            return nothing
        end
    
        push!(payoff_improvements, (player_id, payoff_improvement))
        ### Step 4: Generation of next sampled game
        push!(sampled_game.strategy_sample[player_id], new_strategy)
        update_sampled_game!(sampled_game, player_id, model, timer)
        check_time(timer)

    end
        
    equilibrium_solver.termination_status = IPG.ITERATION_LIMIT
    return nothing
end

function esgm_search!(equilibrium_solver::EquilibriumSolver, model::IPG.IPGModel, max_iter::Integer, dev_tol::Float64, timer::SGMTimer)::Nothing
    players = model.players
    num_players = length(players)
    check_time(timer)
    
    # eSGM algorithm:
    
    ### Initialization of sampled game
    sampled_strategies = initialize_strategies(players, num_players, equilibrium_solver.best_response_optimizer, timer)
    check_time(timer)
    sampled_game = initialize_sampled_game(model, sampled_strategies, timer)
    check_time(timer)

    equilibrium_solver.equilibria = Vector{IPG.Profile}()
    equilibrium_solver.candidate_equilibria = Vector{IPG.Profile}()
    payoff_improvements = Vector{Tuple{Int,Float64}}()

    for iter in 1:max_iter
        ### Master problem
        candidate_equilibria = solve_all(sampled_game, timer, equilibrium_solver.sampled_game_optimizer)

        check_time(timer)
        append!(equilibrium_solver.candidate_equilibria, candidate_equilibria)

        ### Subproblem 1
        new_strategies = Vector{IPG.PureStrategy}()
        player_order = get_player_order(num_players, payoff_improvements)
        check_time(timer)

        for candidate_equilibrium in candidate_equilibria
            deviations = find_deviations(model, candidate_equilibrium, equilibrium_solver.best_response_optimizer, timer, player_order, dev_tol)
            check_time(timer)

            if isempty(deviations) # Equilibrium found
                push!(equilibrium_solver.equilibria, candidate_equilibrium)
            else
                for (payoff_improvement, player_id, new_strategy) in deviations
                    push!(new_strategies, new_strategy)
                    push!(payoff_improvements, (player_id, payoff_improvement))
                end
            end
        end

        if !isempty(new_strategies)
            # Increase sample
            for new_strategy in new_strategies
                player_id = new_strategy.id
                push!(sampled_game.strategy_sample[player_id], new_strategy)
                update_sampled_game!(sampled_game, player_id, model, timer)
                check_time(timer)
            end

            continue
        end

        ### Subproblem 2
        candidate_solutions = find_candidate_solutions(model, sampled_game, equilibrium_solver.best_response_optimizer, timer)
        check_time(timer)

        if !isempty(candidate_solutions)
            # Increase sample
            for candidate_solution in candidate_solutions
                for strat in candidate_solution
                    player_id = strat.id
                    push!(sampled_game.strategy_sample[player_id], strat)
                    update_sampled_game!(sampled_game, player_id, model, timer)
                    check_time(timer)
                end
            end
            continue

        end

        # Terminate
        equilibrium_solver.termination_status = IPG.ENUMERATION_COMPLETE
        return nothing
    end

    equilibrium_solver.termination_status = IPG.ITERATION_LIMIT
    return nothing
end
end