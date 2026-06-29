# Temporary code for some general IPG functions before IPG.jl is implemented

# TODO: add tests for compute_payoff_at_profile

"""
    compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::AbstractVector{<:PureStrategy})::Float64

Compute player `player_id`'s payoff at the pure profile `profile`.
"""
function compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::AbstractVector{<:PureStrategy})::Float64
    player_model = game.players[player_id]
    var_to_param_map = game.var_to_param_maps[player_id]
    payoff_function = JuMP.objective_function(player_model)

    assignments = copy(profile[player_id].variable_values)
    for strategy in profile
        if strategy.id != player_id
            for (variable, value) in strategy.variable_values
                if haskey(var_to_param_map, variable)
                    parameter = var_to_param_map[variable]
                    assignments[parameter] = value
                end
            end
        end
    end

    function get_assigned_value(variable::JuMP.VariableRef) return assignments[variable] end

    payoff_value = JuMP.value(get_assigned_value, payoff_function)
    return Float64(payoff_value)
end

"""
    compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::AbstractVector{<:Strategy})::Float64

Compute player `player_id`'s expected payoff at the profile `profile` if `profile` has atleast one mixed strategy.
Otherwise, the `compute_payoff_at_profile` for pure profiles is called.
"""
function compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::AbstractVector{<:Strategy})::Float64
    if all(strategy -> strategy isa PureStrategy, profile) # Pure profile
        pure_profile = PureStrategy[strategy for strategy in profile]
        return compute_payoff_at_profile(game, player_id, pure_profile)
    end

    # Expected payoff:
    expectation = 0.0
    supports = [strategy isa PureStrategy ? [strategy] : strategy.supp for strategy in profile]
    probabilities = [strategy isa PureStrategy ? [1.0] : strategy.probs for strategy in profile]

    for (probs, strats) in zip(Iterators.product(probabilities...), Iterators.product(supports...))
        prob = prod(probs)
        pure_profile = PureStrategy[strats...]

        expectation += prob * compute_payoff_at_profile(game, player_id, pure_profile)
    end
    
    return expectation
end

"""
    empty_strategy_sample(num_players::Int)

Create an empty strategy sample for `num_players` players.

The returned vector contains an empty `PureStrategy` vector per player.
"""
function empty_strategy_sample(num_players::Int)::Vector{Vector{PureStrategy}}
    [PureStrategy[] for _ in 1:num_players]
end

"""
    get_player_variables(model::IPGModel)::Vector{JuMP.VariableRef}

Get all variables from `model`, excluding parameters.
"""
function get_player_variables(model::JuMP.Model)::Vector{JuMP.VariableRef}
    return filter((var) -> !JuMP.is_parameter(var), JuMP.all_variables(model))
end