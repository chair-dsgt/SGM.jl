function empty_strategy_sample(num_players::Int)
    [PureStrategy[] for _ in 1:num_players]
end

function initialize_player_strategy(id::Int, model::JuMP.Model, optimizer_factory)::PureStrategy
    variables = JuMP.all_variables(model)
    values = JuMP.start_value.(variables)

    if nothing in values # solve feasibility problem
        model_copy, reference_map = JuMP.copy_model(model)

        JuMP.set_optimizer(model_copy, optimizer_factory)
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

function initialize_strategies(players::Vector{JuMP.Model}, num_players::Int, optimizer_factory)
    initial_sampled_strategies = empty_strategy_sample(num_players)

    for i in 1:num_players
        player_model = players[i]
        strategy = initialize_player_strategy(i, player_model, optimizer_factory)
        push!(initial_sampled_strategies[i], strategy)
    end
    
    return initial_sampled_strategies
end
