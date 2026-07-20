using Gurobi, Juniper, Ipopt
using PiecewiseLinApprox
using PiecewiseLinearOpt

# Function to compute Nash equilibria for a NGame instance
"""
    compute_nash_equilibria(my_game::NGame; method::Int=1, timelimit::Float64=300.0, seed::Int=1)

Compute Nash equilibria for a multi-player normal-form game.

# Arguments
- `my_game::NGame`: The game instance (see `NGame` struct).
- `method::Int=1`: (Optional) Which algorithm to use for solving the game.
    - `1`: Use exact MILP/MINLP formulation (default).
    - Other values can be reserved for alternative algorithms (not yet implemented).
- `timelimit::Float64=300.0`: (Optional) Time limit for the solver in seconds. Must be a float.
- `seed::Int=1`: (Optional) Random seed for solver reproducibility.
- `error_rel::Float64=0.01`: (Optional) relative error.
- `error_num::Float64=0.01`: (Optional) numerical precision error.
- `objective_option`: (Optional) whether we maximize the social welfare (true) or no objective (false)
- `methodpwl=:Logarithmic`: (Optional) Method for piecewise linear approximation of the logarithm function. Default is `:Logarithmic`. Other options can be used if you have installed the PiecewiseLinearOpt package. You can also use Gurobi's formulation by setting `methodpwl="GUROBIform"`.

# Returns
A tuple containing the objective value, utilities, strategies, and model objects.
"""
function compute_nash_equilibria(my_game::NGame,method::Int=1, timelimit::Float64=300.0, seed::Int=1, error_rel::Float64=0.01, error_num::Float64=0.01, objective_option::Bool=true, methodpwl=:Logarithmic)
    if methodpwl == "GUROBIform"
        if method == 1
            println("Method =1 and methodpwl=GUROBIform is incompatible. We will use method=2.")
        end
        # Use Gurobi's piecewise linear approximation
        # model, x, y, u, v, z_under, z_over, v_under, v_over = compute_nash_equilibria_GUROBI_PWL(my_game, timelimit, seed, error_rel, error_num)
    else
        if my_game.n <=3 || method != 1
            # Start model
            if Sys.iswindows()
                # run the one below which prevents that in the log we see multiple verifications of the license
                env = Gurobi.Env(Dict{String,Any}("OutputFlag"=>1))
                model = Model(()->Gurobi.Optimizer(env))
            else
                # Start model
                model = Model(Gurobi.Optimizer)
            end
            # For reproducibility purposes
            set_optimizer_attribute(model, "Seed", seed)
        else
            println("Using Juniper with Ipopt for games with more than 3 players")
            optimizer = Juniper.Optimizer
            nl_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0) # print_level is level of verbosity
            model = Model(optimizer_with_attributes(optimizer, "nl_solver"=>nl_solver))
        end

        set_silent(model)
        # Enforce time limit
        set_time_limit_sec(model, timelimit)
        # Restrict to one thread
        MOI.set(model, MOI.NumberOfThreads(), 1)

        # compute pwl for log(x) if method != 1
        if method != 1
            @assert error_rel ≥ 0 "error_rel must be non-negative"
            @assert error_num ≥ 0 "error_num must be non-negative"
            #set_optimizer_attribute(model, "FeasibilityTol", error_num)  # or your desired tolerance
            # compute piecewise linear approximation of log(x) function
            error_abs = (1/my_game.n)*log(1+error_rel)
            # underestimator from error_num to 1
            pwl_under = Linearize(:(log(x)), error_num, 1, Absolute(error_abs); bounding=Under())
            # overestimator from error_num to 1
            pwl_over  = Linearize(:(log(x)), error_num, 1, Absolute(error_abs); bounding=Over()) 
            # add piecewise linear constraints

            # Collect all unique breakpoints to use in the formulation
            x_pts_under = [pwl_under[1].xMin]
            for seg in pwl_under
                push!(x_pts_under, seg.xMax)
            end
            x_pts_over = [pwl_over[1].xMin]
            for seg in pwl_over
                push!(x_pts_over, seg.xMax)
            end
            # Compute the corresponding y values
            y_pts_under = vcat([pwl_under(error_num)],[pwl_under(d) for d in x_pts_under])
            y_pts_over  = vcat([pwl_over(error_num)],[pwl_over(d) for d in x_pts_over])
            x_pts_under = pushfirst!(x_pts_under, 0) # we add manually zero
            x_pts_over = pushfirst!(x_pts_over, 0) # we add manually zero
        end

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

        # auxiliary variables for piecewise linear approximation
        if method != 1
            # define auxiliary variables for piecewise linear approximation
            # z_under = [@variable(model, [1:my_game.strat[i]], lower_bound = -Inf) for i in 1:my_game.n]
            # z_over  = [@variable(model, [1:my_game.strat[i]], lower_bound = -Inf) for i in 1:my_game.n]
            z_under = [Vector{Any}(undef, my_game.strat[j]) for j in 1:my_game.n]
            z_over = [Vector{Any}(undef, my_game.strat[j]) for j in 1:my_game.n]
            for j in 1:my_game.n
                for sj in 1:my_game.strat[j]
                    # Initialize the piecewise linear variables for each strategy of each player
                    z_over[j][sj] = PiecewiseLinearOpt.piecewiselinear(model, x[j][sj], x_pts_over, y_pts_over; method = methodpwl)
                    z_under[j][sj] = PiecewiseLinearOpt.piecewiselinear(model, x[j][sj], x_pts_under, y_pts_under; method =  methodpwl)
                end
            end
            v_over = Dict{Tuple{Tuple{Vararg{Int}}, Int}, Any}()
            v_under = Dict{Tuple{Tuple{Vararg{Int}}, Int}, Any}()
        end

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
            if method == 1
                for profile in profiles
                    @constraint(model, v[profile, i] == my_game.utilities[profile..., i]*prod(x[j][profile[j]] for j in 1:my_game.n if j != i))
                end
            else
                model = pwl_formulation(my_game, model, i, profiles, x_pts_under, x_pts_over, y_pts_under, y_pts_over, z_under, z_over, v_under, v_over, v, methodpwl)
            end
        end
    end
    
    ###### common part for all methods
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

function pwl_formulation(my_game::NGame, model::JuMP.Model, i, profiles, x_pts_under, x_pts_over, y_pts_under, y_pts_over, z_under, z_over, v_under, v_over, v, methodpwl=:Logarithmic)
    for profile in profiles
        if my_game.utilities[profile..., i] == 0
            @constraint(model, v[profile,i] == 0)
        else
            # a*sum(x[j][profile[j]] for j in 1:my_game.n if j != i)+b <= c*(v[profile,i]/my_game.utilities[profile..., i])+d
            v_over[profile,i] = PiecewiseLinearOpt.piecewiselinear(model, v[profile,i]/my_game.utilities[profile..., i], x_pts_over, y_pts_over; method = methodpwl)
            @constraint(model, sum(z_under[j][profile[j]] for j in 1:my_game.n if j != i) <= v_over[profile,i])

            # c*sum(x[j][profile[j]] for j in 1:my_game.n if j != i)+d >= a*(v[profile,i]/my_game.utilities[profile..., i])+b
            v_under[profile,i] = PiecewiseLinearOpt.piecewiselinear(model, v[profile,i]/my_game.utilities[profile..., i], x_pts_under, y_pts_under; method = methodpwl)
            @constraint(model, v_under[profile,i] <= sum(z_over[j][profile[j]] for j in 1:my_game.n if j != i))
        end
    end
    return model
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