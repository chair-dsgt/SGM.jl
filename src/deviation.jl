function find_deviation(model::IPGModel, profile::Profile, optimizer_factory, player_order::Union{Nothing,Vector{Int}} = nothing, dev_tol::Float64 = 1e-3)
    player_order = isnothing(player_order) ? collect(1:length(model.players)) : player_order

    for player_id in player_order
        profile_others = Strategy[strategy for strategy in profile if strategy.id != player_id]

        new_strategy = best_response(model, player_id, profile_others, optimizer_factory)
        new_profile = Strategy[strategy.id == player_id ? new_strategy : strategy for strategy in profile] 

        payoff_improvement = compute_payoff_at_profile(model, player_id, new_profile) - compute_payoff_at_profile(model, player_id, profile)

        if payoff_improvement > dev_tol
            return payoff_improvement, player_id, new_strategy
        end
    end

    return 0.0, nothing, nothing
end

