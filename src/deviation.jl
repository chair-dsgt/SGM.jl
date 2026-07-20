function find_deviation(model::IPG.IPGModel, profile::IPG.Profile, optimizer_factory, timer::SGMTimer, player_order::Union{Nothing,Vector{Int}} = nothing, dev_tol::Float64 = 1e-3)
    player_order = isnothing(player_order) ? collect(1:length(model.players)) : player_order

    for player_id in player_order
        profile_others = IPG.Strategy[strategy for strategy in profile if strategy.id != player_id]
        check_time(timer)

        new_strategy = IPG.best_response(model, player_id, profile_others, optimizer_factory, timelimit = remaining_time(timer))
        check_time(timer)
        new_profile = IPG.Strategy[strategy.id == player_id ? new_strategy : strategy for strategy in profile]

        payoff_improvement = IPG.payoff(model, player_id, new_profile) - IPG.payoff(model, player_id, profile)
        check_time(timer)

        if payoff_improvement > dev_tol
            return payoff_improvement, player_id, new_strategy
        end
    end

    return 0.0, nothing, nothing
end

