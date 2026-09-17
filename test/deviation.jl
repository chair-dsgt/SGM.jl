# Covers: find_deviation (src/deviation.jl:1), SGM's termination test - the
# subroutine that decides whether a candidate equilibrium of the sampled game is
# an equilibrium of the real game.
#
# Lives in SGM.jl: searching for a profitable deviation is a step of the SGM
# algorithm. It calls IPG.best_response, but what is asserted here is the search,
# not the best response.
#
# Adapted from the "Deviation reaction" test item of the earlier IPG.jl
# (github.com/brunompacheco/IPG.jl, test/sgm.jl). find_deviation had no test here
# before.
#
# SCIP is used rather than Gurobi so these run without a licence. The
# best-response problems are Example 5.3's, which SCIP solves exactly.

# Covers: that find_deviation reports a genuine improvement away from an
# equilibrium, and reports none at one.
@testitem "Deviation reaction" setup = [Utilities, SCIPOptimizer] begin
    game = get_example_two_player_game_usingIPG()
    x1 = only(IPG.get_player_variables(game.players[1]))
    x2 = only(IPG.get_player_variables(game.players[2]))
    timer = SGM.SGMTimer(Inf64)

    # The sampled game starts from the players' start values, x = 10 for both.
    sampled = SGM.initialize_strategies(game.players, 2, scip_optimizer, timer)
    profile = IPG.Strategy[IPG.MixedStrategy(id, [1.0], sampled[id]) for id in 1:2]

    @test only(values(only(profile[1].supp).variable_values)) == 10.0
    @test only(values(only(profile[2].supp).variable_values)) == 10.0

    payoff_improvement, player_id, new_strategy = SGM.find_deviation(
        game, profile, scip_optimizer, timer,
    )

    @test player_id !== nothing
    @test new_strategy isa IPG.PureStrategy
    @test new_strategy.id == player_id

    # The reported improvement is exactly the payoff difference the deviation buys.
    deviating_profile = IPG.Strategy[s.id == player_id ? new_strategy : s for s in profile]
    previous_payoff = IPG.payoff(game, player_id, profile)
    new_payoff = IPG.payoff(game, player_id, deviating_profile)

    @test payoff_improvement ≈ new_payoff - previous_payoff atol = 1e-6
    @test payoff_improvement > 0.0

    # Against x_other = 10 the best response is x = 5, worth -25 + 50 = 25
    # instead of -100 + 100 = 0.
    @test only(values(new_strategy.variable_values)) ≈ 5.0 atol = 1e-5
    @test payoff_improvement ≈ 25.0 atol = 1e-5

    # (0, 0) is the equilibrium of Example 5.3, so no player can deviate
    # profitably and find_deviation reports nothing at all.
    equilibrium = IPG.Strategy[
        IPG.PureStrategy(1, Dict(x1 => 0.0)),
        IPG.PureStrategy(2, Dict(x2 => 0.0)),
    ]

    payoff_improvement, player_id, new_strategy = SGM.find_deviation(
        game, equilibrium, scip_optimizer, timer,
    )

    @test payoff_improvement == 0.0
    @test isnothing(player_id)
    @test isnothing(new_strategy)
end

# Covers: the player_order argument of find_deviation (src/deviation.jl:2), which
# selects *which* profitable deviation is returned when several exist. The order
# is what SGM.get_player_order produces, and neither had a test before.
@testitem "Deviation reaction follows the player order" setup = [Utilities, SCIPOptimizer] begin
    game = get_example_two_player_game_usingIPG()
    timer = SGM.SGMTimer(Inf64)

    sampled = SGM.initialize_strategies(game.players, 2, scip_optimizer, timer)
    profile = IPG.Strategy[IPG.MixedStrategy(id, [1.0], sampled[id]) for id in 1:2]

    # The game is symmetric at (10, 10), so both players can deviate and gain the
    # same amount. find_deviation returns the first one in the given order.
    for order in ([1, 2], [2, 1])
        improvement, player_id, _ = SGM.find_deviation(
            game, profile, scip_optimizer, timer, order,
        )

        @test player_id == first(order)
        @test improvement ≈ 25.0 atol = 1e-5
    end

    # The order-producing subroutines agree with that convention.
    @test SGM.get_player_order_fixed_ascending(2, Tuple{Int,Float64}[]) == [1, 2]
    @test SGM.get_player_order_fixed_descending(2, Tuple{Int,Float64}[]) == [2, 1]
    @test sort(SGM.get_player_order_random(2, Tuple{Int,Float64}[])) == [1, 2]

    # With no history recorded, the default falls back to ascending order; once a
    # player has just deviated, it is tried last.
    @test SGM.get_player_order_by_last_deviation(2, Tuple{Int,Float64}[]) == [1, 2]
    @test SGM.get_player_order_by_last_deviation(2, [(1, 25.0)]) == [2, 1]
end

# Covers: find_deviations (src/deviation.jl:23), the eSGM variant that collects
# every profitable deviation instead of stopping at the first.
@testitem "All deviations" setup = [Utilities, SCIPOptimizer] begin
    game = get_example_two_player_game_usingIPG()
    x1 = only(IPG.get_player_variables(game.players[1]))
    x2 = only(IPG.get_player_variables(game.players[2]))
    timer = SGM.SGMTimer(Inf64)

    sampled = SGM.initialize_strategies(game.players, 2, scip_optimizer, timer)
    profile = IPG.Strategy[IPG.MixedStrategy(id, [1.0], sampled[id]) for id in 1:2]

    deviations = SGM.find_deviations(game, profile, scip_optimizer, timer)

    # Both players gain by deviating from (10, 10), and the game is symmetric.
    @test length(deviations) == 2
    @test sort([player_id for (_, player_id, _) in deviations]) == [1, 2]
    for (improvement, player_id, strategy) in deviations
        @test improvement ≈ 25.0 atol = 1e-5
        @test strategy.id == player_id
        @test only(values(strategy.variable_values)) ≈ 5.0 atol = 1e-5
    end

    # At the equilibrium there is nothing to collect.
    equilibrium = IPG.Strategy[
        IPG.PureStrategy(1, Dict(x1 => 0.0)),
        IPG.PureStrategy(2, Dict(x2 => 0.0)),
    ]

    @test isempty(SGM.find_deviations(game, equilibrium, scip_optimizer, timer))
end
