function initialize_sampled_game(model::IPG.IPGModel, strategies::Vector{Vector{IPG.PureStrategy}}, timer::SGMTimer)::Union{PolymatrixSampledGame, NormalFormSampledGame}
    for p in eachindex(model.players)
        check_time(timer)
        if !is_pairwise_payoff(model, p, timer)
            return NormalFormSampledGame(model, strategies, timer)
        end
    end
    return PolymatrixSampledGame(model, strategies, timer)
end


function is_pairwise_payoff(model::IPG.IPGModel, player_id::Int, timer::SGMTimer)::Bool
    if !is_quad_payoff(model, player_id)
        return false
    end

    payoff_function = JuMP.objective_function(model.players[player_id], JuMP.QuadExpr)

    param_to_player = Dict{JuMP.VariableRef, Int}()
    for p in eachindex(model.players)
        check_time(timer)
        if p == player_id 
            continue
        end
        for var in IPG.get_player_variables(model.players[p])
            if haskey(model.var_to_param_maps[player_id], var)
                param = model.var_to_param_maps[player_id][var]
                param_to_player[param] = p
            end
        end
    end

    for (_, var1, var2) in JuMP.quad_terms(payoff_function)
        check_time(timer)
        if haskey(param_to_player, var1) && haskey(param_to_player, var2) && param_to_player[var1] != param_to_player[var2]
            return false
        end
    end

    return true
end

function is_quad_payoff(model::IPG.IPGModel, player_id::Int)::Bool
    try JuMP.objective_function(model.players[player_id], JuMP.QuadExpr)
        return true
    catch
        return false
    end
end

