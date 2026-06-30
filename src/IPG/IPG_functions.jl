# Temporary code for some general IPG functions before IPG.jl is implemented

# TODO: add tests for compute_payoff_at_profile

"""
    compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::Vector{<:PureStrategy})::Float64

Compute player `player_id`'s payoff at the pure profile `profile`.
"""
function compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::Vector{<:PureStrategy})::Float64
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
    compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::Profile)::Float64

Compute player `player_id`'s expected payoff at the profile `profile` if `profile` has atleast one mixed strategy.
Otherwise, the `compute_payoff_at_profile` for pure profiles is called.
"""
function compute_payoff_at_profile(game::IPGModel, player_id::Int, profile::Profile)::Float64
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
    get_player_variables(model::JuMP.Model)::Vector{JuMP.VariableRef}

Get all variables from `model`, excluding parameters.
"""
function get_player_variables(model::JuMP.Model)::Vector{JuMP.VariableRef}
    return filter((var) -> !JuMP.is_parameter(var), JuMP.all_variables(model))
end

"""
    get_best_response_model(model::IPGModel, player_id::Int, profile::Profile[, optimizer_factory])::Tuple{JuMP.Model, JuMP.ReferenceMap}

Build the best-response optimization problem of the player `player_id` from the IPG model `model`, with respect to `profile`.

Note that the resulting model will be a copy of `player_id`'s optimization problem, with the same variable names, but different references.

# Arguments
- `model`: the IPG model representing the game.
- `player_id::Int`: number of the player whose best-response problem is built.
- `profile::Profile`: should contain the strategies of all other players in the game to which the player belongs.
- `optimizer_factory`: if specified, sets the optimizer of the best response model.
"""
function get_best_response_model(model::IPGModel, player_id::Int, profile::Profile, optimizer_factory = nothing)::Tuple{JuMP.Model, JuMP.ReferenceMap}
    player_model = model.players[player_id]
    var_to_param_map = model.var_to_param_maps[player_id]
    best_response_model, reference_map = JuMP.copy_model(player_model)

    if all(strategy -> strategy isa PureStrategy, profile) # Pure profile
        for strategy in profile
            for (var, val) in strategy.variable_values
                if haskey(var_to_param_map, var)
                    param = var_to_param_map[var]
                    best_response_param = reference_map[param]
    
                    JuMP.set_parameter_value(best_response_param, val)
                end
            end
        end
    else # Profile containing atleast one mixed strategy
        payoff_function = JuMP.objective_function(player_model, JuMP.QuadExpr)
        
        expected_payoff = zero(JuMP.QuadExpr)
        
        supports = [strategy isa PureStrategy ? [strategy] : strategy.supp for strategy in profile]
        probabilities = [strategy isa PureStrategy ? [1.0] : strategy.probs for strategy in profile]
        
        for (probs, strats) in zip(Iterators.product(probabilities...), Iterators.product(supports...))
            prob = prod(probs)

            parameter_values = Dict{JuMP.VariableRef, Float64}()
            for strat in strats
                for (var, val) in strat.variable_values
                    if haskey(var_to_param_map, var)
                        param = var_to_param_map[var]
                        parameter_values[param] = val
                    end
                end
            end

            expected_payoff += prob * replace_param_with_val(payoff_function, parameter_values, reference_map)
        end
        JuMP.set_objective_function(best_response_model, expected_payoff)
    end

    if optimizer_factory !== nothing
        JuMP.set_optimizer(best_response_model, optimizer_factory)
    end

    return best_response_model, reference_map
end

"""
    best_response(model::IPGModel, player_id::Int, profile::Profile, optimizer_factory)::PureStrategy

Return the best response strategy of the player `player_id` from the IPG model `model`, with respect to `profile`.

This function builds the best-response model, calls `optimize!` on it, and returns the resulting strategy.

# Arguments
- `model`: the IPG model representing the game.
- `player_id::Int`: number of the player that will respond optimally to profile.
- `profile::Profile`: should contain the strategies of all other players in the game to which the player belongs.
- `optimizer_factory`: sets the optimizer of the best response model.
"""
function best_response(model::IPGModel, player_id::Int, profile::Profile, optimizer_factory)::PureStrategy
    player_model = model.players[player_id]

    best_response_model, reference_map = get_best_response_model(model, player_id, profile, optimizer_factory)
    JuMP.set_silent(best_response_model)
    JuMP.optimize!(best_response_model)

    variable_values = Dict{JuMP.VariableRef, Float64}()
    for var in get_player_variables(player_model)
        best_response_var = reference_map[var]
        variable_values[var] = JuMP.value(best_response_var)
    end

    return PureStrategy(player_id, variable_values)
end

"""
    replace_param_with_val(payoff::JuMP.QuadExpr, parameter_values::Dict{JuMP.VariableRef, Float64}, reference_map::JuMP.ReferenceMap)::JuMP.QuadExpr

Replace all parameters in `payoff` by their associated value in `parameter_values`.

Variables that are not parameters stay variables in the returned payoff.
"""
function replace_param_with_val(payoff::JuMP.QuadExpr, parameter_values::Dict{JuMP.VariableRef, Float64}, reference_map::JuMP.ReferenceMap)::JuMP.QuadExpr
    new_payoff = zero(JuMP.QuadExpr)
    new_payoff += JuMP.constant(payoff) # Constant term

    # Linear terms
    for (coefficient, variable) in JuMP.linear_terms(payoff) 
        if haskey(parameter_values, variable)
            new_payoff += coefficient * parameter_values[variable] # Replace parameter with value
        else
            new_payoff += coefficient * reference_map[variable] # Keep variable
        end
    end

    # Quadratic terms
    for (coefficient, variable1, variable2) in JuMP.quad_terms(payoff)
        if haskey(parameter_values, variable1)
            factor1 = parameter_values[variable1] # Replace parameter with value
        else
            factor1 = reference_map[variable1] # Keep variable
        end
        if haskey(parameter_values, variable2)
            factor2 = parameter_values[variable2] # Replace parameter with value
        else
            factor2 = reference_map[variable2] # Keep variable
        end 
        new_payoff += coefficient * factor1 * factor2
    end

    return new_payoff
end