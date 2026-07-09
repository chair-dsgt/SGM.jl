"""
    initialize_player_strategy(id::Int, model::JuMP.Model, optimizer_factory)::PureStrategy

Construct an initial pure strategy for player number `id`.

If every variable has a start value, these values are used directly. Otherwise, a copy of the 
player's model `model` is solved as a feasibility problem using `optimizer_factory`, and the resulting
variable values are used.
"""
function initialize_player_strategy(id::Int, model::JuMP.Model, optimizer_factory, timelimit::Float64)::PureStrategy
    variables = get_player_variables(model)
    values = JuMP.start_value.(variables)

    if nothing in values # solve feasibility problem
        model_copy, reference_map = JuMP.copy_model(model)

        JuMP.set_optimizer(model_copy, optimizer_factory)
        if isfinite(timelimit) JuMP.set_time_limit_sec(model_copy, timelimit) end
        JuMP.@objective(model_copy, JuMP.MOI.FEASIBILITY_SENSE, 0)
        JuMP.set_silent(model_copy)
        JuMP.optimize!(model_copy)

        values = [JuMP.value(reference_map[variable]) for variable in variables]
    end

    variable_values = Dict{JuMP.VariableRef, Float64}()
    for (variable, value) in zip(variables, values)
        variable_values[variable] = value
    end

    return PureStrategy(id, variable_values)
end


"""
    initialize_strategies(players::Vector{JuMP.Model}, num_players::Int, optimizer_factory)::Vector{Vector{PureStrategy}}

Initialize the sampled strategies for all players.

Returns a `Vector{Vector{PureStrategy}}` in which entry `i` contains the initial sampled pure strategy of player `i`.

# Arguments 

* `players::Vector{JuMP.Model}`: JuMP models representing the players' optimization problems. 
* `num_players::Int`: Total number of players in the game. 
* `optimizer_factory`: Optimizer factory used if a feasibility problem must be solved to initialize a player's strategy.
"""
function initialize_strategies(players::Vector{JuMP.Model}, num_players::Int, optimizer_factory, timer::SGMTimer)::Vector{Vector{PureStrategy}}
    initial_sampled_strategies = empty_strategy_sample(num_players)
    check_time(timer)

    for i in 1:num_players
        player_model = players[i]
        strategy = initialize_player_strategy(i, player_model, optimizer_factory, remaining_time(timer))
        check_time(timer)
        push!(initial_sampled_strategies[i], strategy)
    end
    
    return initial_sampled_strategies
end
