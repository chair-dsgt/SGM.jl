# Function to compute Nash equilibria for a NGame instance
"""
    compute_nash_equilibria(my_game::NGame; timelimit::Float64=300.0, seed::Int=1)

Compute Nash equilibria for a multi-player normal-form game.

# Arguments
- `my_game::NGame`: The game instance (see `NGame` struct).
- `timelimit::Float64=300.0`: (Optional) Time limit for the solver in seconds. Must be a float.
- `seed::Int=1`: (Optional) Random seed for solver reproducibility.
- `error_rel::Float64=0.01`: (Optional) relative error.
- `error_num::Float64=0.01`: (Optional) numerical precision error.
- `objective_option`: (Optional) whether we maximize the social welfare (true) or no objective (false)

# Returns
A tuple containing the objective value, utilities, strategies, and model objects.
"""
function compute_nash_equilibria(my_game::NGame, optimizer_factory, timelimit::Float64=300.0, error_rel::Float64=0.01, objective_option::Bool=true)
    # Start model
    model = Model(optimizer_factory)

    set_silent(model)
    # Enforce time limit
    set_time_limit_sec(model, timelimit)

    # Minimum and maximum utility of each player
    # For each player i, find the minimum utility across all profiles for that player
    mins = [minimum(view(my_game.utilities, ntuple(_ -> Colon(), ndims(my_game.utilities)-1)..., i)) for i in 1:my_game.n]
    maxs = [maximum(view(my_game.utilities, ntuple(_ -> Colon(), ndims(my_game.utilities)-1)..., i)) for i in 1:my_game.n]

    # Variables 
    # define probability distribution for each player
    x = [JuMP.@variable(model, [1:my_game.strat[i]], lower_bound = 0.0, upper_bound = 1.0) for i = 1:my_game.n] 
    # define indicator variable for each strategy of each player
    y = [JuMP.@variable(model, [1:my_game.strat[i]], Bin) for i = 1:my_game.n]
    # define expected utility value for each player
    JuMP.@variable(model, u[i = 1:my_game.n], lower_bound=mins[i]*(1-sign(mins[i])*error_rel), upper_bound=maxs[i]*(1+sign(maxs[i])*error_rel))
    # define auxiliary variable related with non-linear terms
    # generate all possible pure profiles of strategies
    profiles = Iterators.product((1:s for s in my_game.strat)...)
    JuMP.@variable(model, v[profile in profiles, i=1:my_game.n], lower_bound=min(0,my_game.utilities[profile...,i])*(1-sign(min(0,my_game.utilities[profile...,i]))*error_rel), upper_bound=max(0,my_game.utilities[profile...,i])*(1+sign(max(0,my_game.utilities[profile...,i]))*error_rel))

    # Constraints
    # if x>0 then y=1
    @constraint(model, y .>= x) # componentwise constraint
    # precomputation, for each player i and strategty si, of all profiles where si is played
    aux_profiles = auxiliary_profiles(my_game, profiles) # aux_profiles[i][si] contains all profiles where player i plays strategy si
    for i in 1:my_game.n
        # add probability distribution constraint
        @constraint(model, sum(x[i]) == 1)
        # no regret constraints
        for si in 1:my_game.strat[i]
            # We could do as below but I think it is more efficient to precompute the profiles in profit_si
            #profit_si = sum(v[profile,i] for profile in profiles if profile[i] == si) 
            profit_si = sum(v[profile,i] for profile in aux_profiles[i][si])
            @constraint(model, profit_si <= u[i])
            @constraint(model, y[i][si] --> {profit_si == u[i]})
        end
        # The non-linear terms
        for profile in profiles
            @constraint(model, v[profile, i] == my_game.utilities[profile..., i]*prod(x[j][profile[j]] for j in 1:my_game.n if j != i))
        end
    end
    
    # Objective function: compute equilibrium with largest welfare
    if objective_option
        @objective(model, Max, sum(u))
    else
        @objective(model, Min, 0)  # No objective, just feasibility
    end

    #write_to_file(model, "output.lp")

    # Solve model
    JuMP.optimize!(model)

    println("status: ",termination_status(model), " primal status ", primal_status(model))

    # Solution
    if termination_status(model) == MOI.OPTIMAL && primal_status(model) == MOI.FEASIBLE_POINT
        println("Model is solved and feasible and solving time is ",solve_time(model))
        return objective_value(model), value.(u), [value.(x[p]) for p in 1:my_game.n], [value.(y[p]) for p in 1:my_game.n], model, y, u, x, solve_time(model)
    elseif termination_status(model) == MOI.LOCALLY_SOLVED && primal_status(model) == MOI.FEASIBLE_POINT
        println("Model is locally solved and feasible and solving time is ",solve_time(model))
        return objective_value(model), value.(u), [value.(x[p]) for p in 1:my_game.n], [value.(y[p]) for p in 1:my_game.n], model, y, u, x, solve_time(model)
    elseif termination_status(model) == MOI.TIME_LIMIT && primal_status(model) == MOI.FEASIBLE_POINT
        println("Best feasible solution found within the time limit: ", solve_time(model))
        return objective_value(model), value.(u), [value.(x[p]) for p in 1:my_game.n], [value.(y[p]) for p in 1:my_game.n], model, y, u, x, solve_time(model)
    else
        println("Model is not solved and/or not feasible.")
        return "NaN","NaN","NaN", "NaN", model, y, u, x, "tl"
    end
end

function auxiliary_profiles(my_game::NGame, profiles)
    profiles = collect(profiles)  # Ensure it's a vector of tuples
    profile_map = [Dict{Int, Vector{Tuple{Vararg{Int}}}}() for i in 1:my_game.n]
    for profile in profiles
        for i in 1:my_game.n
            si = profile[i]
            if !haskey(profile_map[i], si)
                profile_map[i][si] = Tuple{Vararg{Int}}[]
            end
            push!(profile_map[i][si], profile)
        end
    end
    return profile_map
end