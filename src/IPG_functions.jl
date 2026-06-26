# Temporary code for some general IPG functions before IPG.jl is implemented

function compute_payoff_at_profile(player_id::Int, player_model::JuMP.Model, profile::Profile, var_to_param_map::Dict{JuMP.VariableRef, JuMP.VariableRef})::Float64
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