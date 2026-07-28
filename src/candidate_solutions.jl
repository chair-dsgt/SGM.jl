"Function for Subproblem 2 of the eSGM algorithm."
function find_candidate_solutions(model::IPG.IPGModel, sampled_game::Union{PolymatrixSampledGame, NormalFormSampledGame}, optimizer_factory, timer::SGMTimer)::Vector{IPG.Profile}
    candidate_solutions = Vector{IPG.Profile}()

    for player in 1:length(model.players)
        new_model, variable_maps = copy_player_models(model, timer)

        JuMP.set_optimizer(new_model, optimizer_factory)

        JuMP.set_silent(new_model)

        payoff = copy_player_payoff(model, player, variable_maps, timer)
        check_time(timer)

        if JuMP.objective_sense(model.players[player]) == JuMP.MAX_SENSE
            JuMP.@objective(new_model, Max, payoff)
        elseif JuMP.objective_sense(model.players[player]) == JuMP.MIN_SENSE
            JuMP.@objective(new_model, Max, -payoff)
        else 
            throw(ArgumentError("Payoff sense must be max or min"))
        end

        add_constraints_21!(model, new_model, sampled_game, variable_maps, timer)
        check_time(timer)

        # TODO add all the other constraints

"""
        while true
            """
            if isfinite(remaining_time(timer)) JuMP.set_time_limit_sec(new_model, remaining_time(timer)) end

            JuMP.optimize!(new_model)
    
            if !JuMP.is_solved_and_feasible(new_model)
                break
            end
    
            candidate_solution = get_candidate_solution(model, variable_maps)
            
            if is_new_candidate(candidate_solution, sampled_game) # 22
                push!(candidate_solutions, candidate_solution)
            end
    """
            add_exclusion_cut!(
                new_model,
                model,
                variable_maps,
                candidate_solution,
            )
              
        end"""

    end

    return candidate_solutions
end

"Copies all player variables and constraints into a new JuMP model"
function copy_player_models(model::IPG.IPGModel, timer::SGMTimer)::Tuple{JuMP.Model, Vector{Dict{JuMP.VariableRef, JuMP.VariableRef}}}
    new_model = JuMP.Model()
    variable_maps = Vector{Dict{JuMP.VariableRef, JuMP.VariableRef}}() # Maps the players' variables to the new copied variables

    for player in 1:length(model.players)

        variable_map = Dict{JuMP.VariableRef, JuMP.VariableRef}()

        for var in IPG.get_player_variables(model.players[player])
            check_time(timer)
            copied_var = copy_player_variable!(new_model, var, player, timer)
            variable_map[var] = copied_var
        end

        push!(variable_maps, variable_map)

        for constraint in JuMP.all_constraints(model.players[player], include_variable_in_set_constraints = true)
            check_time(timer)
            copy_player_constraint!(new_model, variable_map, constraint, timer)
        end
    end

    return new_model, variable_maps
end

function copy_player_variable!(model::JuMP.Model, var::JuMP.VariableRef, player_id::Int, timer::SGMTimer)::JuMP.VariableRef
    name = "$(player_id)_$(JuMP.name(var))"

    if JuMP.is_binary(var)
        new_var = JuMP.@variable(model, binary = true, base_name = name)
    elseif JuMP.is_integer(var)
        new_var = JuMP.@variable(model, integer = true, base_name = name)
    else
        new_var = JuMP.@variable(model, base_name = name)
    end

    if JuMP.has_lower_bound(var)
        JuMP.set_lower_bound(new_var, JuMP.lower_bound(var))
    end

    if JuMP.has_upper_bound(var)
        JuMP.set_upper_bound(new_var, JuMP.upper_bound(var))
    end

    check_time(timer)

    return new_var
end

function copy_player_constraint!(model::JuMP.Model, variable_map::Dict{JuMP.VariableRef, JuMP.VariableRef}, constraint, timer::SGMTimer)::Nothing
    constraint_object = JuMP.constraint_object(constraint)
    constraint_expr = constraint_object.func

    if constraint_expr isa JuMP.VariableRef 
        return nothing # These constraints have already been taken care of when copying variables
    
    elseif constraint_expr isa JuMP.AffExpr
        new_constraint_expr = JuMP.AffExpr()
        new_constraint_expr += JuMP.constant(constraint_expr)

        for (coef, var) in JuMP.linear_terms(constraint_expr)
            new_constraint_expr += coef * variable_map[var]
        end
    
    elseif constraint_expr isa JuMP.QuadExpr
        new_constraint_expr = JuMP.QuadExpr()
        new_constraint_expr += JuMP.constant(constraint_expr)

        for (coef, var) in JuMP.linear_terms(constraint_expr)
            new_constraint_expr += coef * variable_map[var]
        end

        for (coef, var1, var2) in JuMP.quad_terms(constraint_expr)
            new_constraint_expr += coef * variable_map[var1] * variable_map[var2]
        end

    else
        throw(ArgumentError("Constraint type $(typeof(constraint_expr)) is not supported."))
    end

    check_time(timer)

    JuMP.add_constraint(model, JuMP.build_constraint(error, new_constraint_expr, constraint_object.set))

    return nothing
end

function copy_player_payoff(model::IPG.IPGModel, player_id::Int, variable_maps::Vector{Dict{JuMP.VariableRef, JuMP.VariableRef}}, timer::SGMTimer; strategy::Union{Nothing, IPG.PureStrategy} = nothing)
    payoff = JuMP.objective_function(model.players[player_id])

    if payoff isa Real
        return payoff
    end

    if payoff isa JuMP.VariableRef
        if strategy !== nothing && haskey(strategy.variable_values, payoff)
            return strategy.variable_values[payoff]
        end

        if haskey(variable_maps[player_id], payoff)
            return variable_maps[player_id][payoff]
        else
            return get_other_player_copied_var(model, player_id, payoff, variable_maps, timer)
        end
    end

    if payoff isa JuMP.AffExpr
        new_payoff = JuMP.AffExpr()
        new_payoff += JuMP.constant(payoff)

        for (coef, var) in JuMP.linear_terms(payoff)
            if strategy !== nothing && haskey(strategy.variable_values, var)
                new_payoff += coef * strategy.variable_values[var]
            elseif haskey(variable_maps[player_id], var)
                new_payoff += coef * variable_maps[player_id][var]
            else
                new_payoff += coef * get_other_player_copied_var(model, player_id, var, variable_maps, timer)
            end
        end

        return new_payoff
    end

    if payoff isa JuMP.QuadExpr
        new_payoff = JuMP.QuadExpr()
        new_payoff += JuMP.constant(payoff)

        for (coef, var) in JuMP.linear_terms(payoff)
            if strategy !== nothing && haskey(strategy.variable_values, var)
                new_payoff += coef * strategy.variable_values[var]
            elseif haskey(variable_maps[player_id], var)
                new_payoff += coef * variable_maps[player_id][var]
            else
                new_payoff += coef * get_other_player_copied_var(model, player_id, var, variable_maps, timer)
            end
        end

        for (coef, var1, var2) in JuMP.quad_terms(payoff)
            if strategy !== nothing && haskey(strategy.variable_values, var1)
                new_var1 = strategy.variable_values[var1]
            elseif haskey(variable_maps[player_id], var1)
                new_var1 = variable_maps[player_id][var1]
            else
                new_var1 = get_other_player_copied_var(model, player_id, var1, variable_maps, timer)
            end

            if strategy !== nothing && haskey(strategy.variable_values, var2)
                new_var2 = strategy.variable_values[var2]
            elseif haskey(variable_maps[player_id], var2)
                new_var2 = variable_maps[player_id][var2]
            else
                new_var2 = get_other_player_copied_var(model, player_id, var2, variable_maps, timer)
            end

            new_payoff += coef * new_var1 * new_var2
        end

        return new_payoff
    end
    check_time(timer)

    throw(ArgumentError("Payoff type $(typeof(payoff)) is not supported."))
end

function get_other_player_copied_var(model::IPG.IPGModel, player_id::Int, parameter::JuMP.VariableRef, variable_maps::Vector{Dict{JuMP.VariableRef, JuMP.VariableRef}}, timer::SGMTimer)::JuMP.VariableRef
    for (og_var, param) in model.var_to_param_maps[player_id]
        if param == parameter
            for player in 1:length(model.players)
                if haskey(variable_maps[player], og_var)
                    return variable_maps[player][og_var]
                end
            end
        end
    end
    check_time(timer)

    throw(ArgumentError("Could not find a copied variable for the parameter $(parameter)."))
end

function add_constraints_21!(model::IPG.IPGModel, new_model::JuMP.Model, sampled_game::Union{PolymatrixSampledGame, NormalFormSampledGame}, variable_maps::Vector{Dict{JuMP.VariableRef, JuMP.VariableRef}}, timer::SGMTimer)
    for player in 1:length(model.players)
        candidate_payoff = copy_player_payoff(model, player, variable_maps, timer)

        for sampled_strategy in sampled_game.strategy_sample[player]
            sampled_payoff = copy_player_payoff(model, player, variable_maps, timer; strategy = sampled_strategy)

            if JuMP.objective_sense(model.players[player]) == JuMP.MAX_SENSE
                JuMP.@constraint(new_model, candidate_payoff >= sampled_payoff)
            elseif JuMP.objective_sense(model.players[player]) == JuMP.MIN_SENSE
                JuMP.@constraint(new_model, candidate_payoff <= sampled_payoff)
            else
                throw(ArgumentError("Payoff sense must be max or min"))
            end

            check_time(timer)
        end
    end

    return nothing
end

function get_candidate_solution(model::IPG.IPGModel, variable_maps::Vector{Dict{JuMP.VariableRef, JuMP.VariableRef}})::IPG.Profile
    profile = IPG.PureStrategy[]

    for player in 1:length(model.players)
        variable_values = Dict{JuMP.VariableRef, Float64}()

        for (og_var, copied_var) in variable_maps[player]
            variable_values[og_var] = JuMP.value(copied_var)
        end

        push!(profile, IPG.PureStrategy(player, variable_values))
    end

    return profile
end

function is_new_candidate(candidate_solution::IPG.Profile, sampled_game::Union{PolymatrixSampledGame, NormalFormSampledGame})::Bool
    for strategy in candidate_solution
        player_id = strategy.id
        strategy_has_been_sampled = false

        for sampled_strategy in sampled_game.strategy_sample[player_id]
            same_strategy = true 

            for (var, val) in strategy.variable_values
                if !isapprox(val, sampled_strategy.variable_values[var]; atol = 1e-6) 
                    same_strategy = false
                    break
                end
            end

            if same_strategy
                strategy_has_been_sampled = true
                break
            end
        end

        if !strategy_has_been_sampled
            return true
        end
    end

    return false
end