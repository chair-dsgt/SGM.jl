# TODO: refactor this into a submodule of SGM

const Polymatrix = Dict{Tuple{Int, Int}, Matrix{Float64}} 

mutable struct PolymatrixSampledGame
    strategy_sample::Vector{Vector{PureStrategy}}
    polymatrix::Polymatrix
end

function PolymatrixSampledGame(model::IPGModel, strategies::Vector{Vector{PureStrategy}}, timer::SGMTimer)::PolymatrixSampledGame
    return PolymatrixSampledGame(strategies, get_polymatrix(model, strategies, timer))
end

# TODO: add tests for the function below
function get_polymatrix_twoplayers(game::IPGModel, strategies::Vector{Vector{PureStrategy}}, timer::SGMTimer)::Polymatrix
    # Initialization
    polymatrix = Polymatrix()
    polymatrix[(1,1)] = zeros(length(strategies[1]), length(strategies[1]))
    polymatrix[(2,2)] = zeros(length(strategies[2]), length(strategies[2]))
    polymatrix[(1,2)] = zeros(length(strategies[1]), length(strategies[2]))
    polymatrix[(2,1)] = zeros(length(strategies[2]), length(strategies[1]))

    for i1 in eachindex(strategies[1])
        for i2 in eachindex(strategies[2])
            check_time(timer)
            profile = [strategies[1][i1], strategies[2][i2]]
            polymatrix[(1,2)][i1,i2] = compute_payoff_at_profile(game, 1, profile)
            polymatrix[(2,1)][i2,i1] = compute_payoff_at_profile(game, 2, profile)
        end
    end

    return polymatrix
end

function get_polymatrix_bilateral(game::IPGModel, strategies::Vector{Vector{PureStrategy}}, timer::SGMTimer)::Polymatrix
    num_players = length(game.players)
    polymatrix = Polymatrix()

    # compute utility of each player `p` using the `i_p`-th strategy against player `k`
    # using the `i_k`-th strategy
    for p in 1:num_players
        for k in 1:num_players
            check_time(timer)
            polymatrix[(p,k)] = zeros(length(strategies[p]), length(strategies[k]))

            if k != p
                for (i_p, x_p) in enumerate(strategies[p])
                    self_payoff = compute_self_payoff(game, p, x_p)
                    check_time(timer)

                    for (i_k, x_k) in enumerate(strategies[k])
                        polymatrix[(p,k)][i_p,i_k] = self_payoff / (num_players - 1) + compute_bilateral_payoff(game, p, x_p, x_k)
                        check_time(timer)
                    end
                end
            end
        end
    end

    return polymatrix
end

function get_polymatrix(game::IPGModel, strategies::Vector{Vector{PureStrategy}}, timer::SGMTimer)::Polymatrix
    if length(game.players) < 2
        game.optimizer.termination_status = INVALID_MODEL
        error("An IPG must have atleast 2 players")
    elseif length(game.players) == 2
        return get_polymatrix_twoplayers(game, strategies, timer)
    else
        return get_polymatrix_bilateral(game, strategies, timer)
    end
end

function update_sampled_game!(sampled_game::PolymatrixSampledGame, p::Int, game::IPGModel, timer::SGMTimer)::Nothing
    polymatrix = sampled_game.polymatrix
    strategies = sampled_game.strategy_sample

    other_players = deleteat!(collect(1:length(game.players)), p) # Other players' ids 

    old_num_strats_p = size(polymatrix[(p, other_players[1])], 1) # Number of player p's strategies already stored in polymatrix

    sub_strategies = copy(strategies)
    sub_strategies[p] = strategies[p][(old_num_strats_p + 1):end]
    check_time(timer)
    new_strats_polymatrix = get_polymatrix(game, sub_strategies, timer)

    for k in other_players
        check_time(timer)
        polymatrix[(p,k)] = [polymatrix[(p,k)]; new_strats_polymatrix[(p,k)]]
        polymatrix[(k,p)] = [polymatrix[(k,p)] new_strats_polymatrix[(k,p)]] 
    end
    polymatrix[(p,p)] = Matrix(Diagonal([diag(polymatrix[(p,p)]); diag(new_strats_polymatrix[(p,p)])]))

    return nothing
end

function negative_polymatrix_preprocessing!(polymatrix::Polymatrix)::Polymatrix
    offset = 0.0
    for k in keys(polymatrix)
        offset = min(offset, minimum(polymatrix[k]))
    end
    for k in keys(polymatrix)
        polymatrix[k] = polymatrix[k] .- offset
    end
    return polymatrix
end

function compute_self_payoff(game::IPGModel, player_id::Int, strategy::PureStrategy)::Float64
    payoff_function = JuMP.objective_function(game.players[player_id], JuMP.QuadExpr)

    variable_values = strategy.variable_values # Should only contain variables owned by this player

    payoff_value = JuMP.constant(payoff_function) # Constant terms

    # Linear terms involving only this player
    for (coefficient, variable) in JuMP.linear_terms(payoff_function)
        if haskey(variable_values, variable)
            payoff_value += coefficient * variable_values[variable]
        end
    end

    # Quadratic terms involving only this player
    for (coefficient, variable1, variable2) in JuMP.quad_terms(payoff_function)
        if haskey(variable_values, variable1) && haskey(variable_values, variable2)
            payoff_value += coefficient * variable_values[variable1] * variable_values[variable2]
        end
    end

    return Float64(payoff_value)
end

function compute_bilateral_payoff(game::IPGModel, player_id::Int, player_strategy::PureStrategy, other_strategy::PureStrategy)::Float64
    payoff_function = JuMP.objective_function(game.players[player_id], JuMP.QuadExpr)

    player_variable_values = player_strategy.variable_values # Should only contain variables owned by the player

    var_to_param_map = game.var_to_param_maps[player_id]
    other_parameter_values = Dict{JuMP.VariableRef,Float64}()
    for (other_variable, value) in other_strategy.variable_values
        if haskey(var_to_param_map, other_variable)
            parameter = var_to_param_map[other_variable]
            other_parameter_values[parameter] = value
        end
    end

    payoff_value = 0.0

    # Linear terms involving only the other player
    for (coefficient, variable) in JuMP.linear_terms(payoff_function)
        if haskey(other_parameter_values, variable)
            payoff_value += coefficient * other_parameter_values[variable]
        end
    end

    # Quadratic terms involving the other player
    for (coefficient, variable1, variable2) in JuMP.quad_terms(payoff_function)
        if haskey(other_parameter_values, variable1) && haskey(other_parameter_values, variable2)
            payoff_value += coefficient * other_parameter_values[variable1] * other_parameter_values[variable2]
        elseif haskey(other_parameter_values, variable1) && haskey(player_variable_values, variable2)
            payoff_value += coefficient * other_parameter_values[variable1] * player_variable_values[variable2]
        elseif haskey(player_variable_values, variable1) && haskey(other_parameter_values, variable2)
            payoff_value += coefficient * player_variable_values[variable1] * other_parameter_values[variable2]
        end
    end

    return Float64(payoff_value)
end