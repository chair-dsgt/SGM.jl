# Covers: the polymatrix sampled game (src/SampledGames/Polymatrix/).
#
# Lives in SGM.jl: a polymatrix is the approximation of the game that the SGM
# algorithm solves at each iteration. It is SGM's own data structure and has no
# counterpart in IPG.jl.
#
# Adapted from test/polymatrix.jl of the earlier IPG.jl
# (github.com/brunompacheco/IPG.jl), where the SGM algorithm still lived inside
# IPG. The module had no tests here before.
#
# The fixture is Example 5.3: each player maximizes -x_p^2 + x_p * x_other, so
# the payoff splits cleanly into a self part -x_p^2 and a bilateral part
# x_p * x_other, which is what a polymatrix representation requires.

# Covers: compute_self_payoff, compute_bilateral_payoff, get_polymatrix_bilateral,
# get_polymatrix_twoplayers (src/SampledGames/Polymatrix/polymatrix_game.jl), and
# that update_sampled_game! grows a polymatrix to the same result as building it
# in one shot.
#
# No optimizer is involved: a polymatrix is pure payoff arithmetic over strategies
# that are already sampled.
@testitem "Polymatrix computation" setup = [Utilities] begin
    game = get_example_two_player_game_usingIPG()
    x1 = only(IPG.get_player_variables(game.players[1]))
    x2 = only(IPG.get_player_variables(game.players[2]))
    timer = SGM.SGMTimer(Inf64)

    # Two sampled strategies per player: x = 10 and x = 5.
    strategies = [
        [IPG.PureStrategy(1, Dict(x1 => 10.0)), IPG.PureStrategy(1, Dict(x1 => 5.0))],
        [IPG.PureStrategy(2, Dict(x2 => 10.0)), IPG.PureStrategy(2, Dict(x2 => 5.0))],
    ]

    # The self payoff keeps only the terms in the player's own variables.
    for player_id in 1:2
        for strategy in strategies[player_id]
            x = only(values(strategy.variable_values))
            @test SGM.compute_self_payoff(game, player_id, strategy) == -x^2
        end
    end

    # The bilateral payoff keeps only the cross terms. This game is symmetric, so
    # the two players agree on the value of the pair (10, 10).
    @test SGM.compute_bilateral_payoff(game, 1, strategies[1][1], strategies[2][1]) ==
          SGM.compute_bilateral_payoff(game, 2, strategies[2][1], strategies[1][1]) ==
          10.0 * 10.0

    polymatrix = SGM.get_polymatrix_bilateral(game, strategies, timer)

    # Block (p, k) has one row per strategy of p and one column per strategy of k.
    # The diagonal blocks stay zero: a player is never paired against itself.
    @test polymatrix[(1, 1)] == polymatrix[(2, 2)] == zeros(2, 2)

    # Entry [i, j] is the self payoff of p's i-th strategy, split over the other
    # players, plus the bilateral payoff against k's j-th strategy. With x1 = 10
    # against x2 = 5 that is -100 + 50 = -50, and with x1 = 5 against x2 = 10 it
    # is -25 + 50 = 25.
    @test polymatrix[(1, 2)] == polymatrix[(2, 1)] == [0.0 -50.0; 25.0 0.0]

    # With two players the general bilateral construction and the specialized
    # two-player one must agree, since dividing the self payoff by (n - 1) leaves
    # it untouched and self + bilateral is then the whole payoff.
    @test SGM.get_polymatrix_twoplayers(game, strategies, timer) == polymatrix

    # Growing the sample one strategy at a time must reach the same polymatrix as
    # building it from the full sample. This is what SGM does between iterations.
    incremental = SGM.initialize_strategies(game.players, 2, mock_feasibility_optimizer, timer)
    sampled_game = SGM.PolymatrixSampledGame(game, incremental, timer)

    # initialize_strategies seeds from the start values, which are x = 10.
    @test only(values(only(sampled_game.strategy_sample[1]).variable_values)) == 10.0
    @test size(sampled_game.polymatrix[(1, 2)]) == (1, 1)

    for player_id in 1:2
        push!(sampled_game.strategy_sample[player_id], strategies[player_id][2])
        SGM.update_sampled_game!(sampled_game, player_id, game, timer)
    end

    @test sampled_game.polymatrix == polymatrix
end

# Covers: solve_PNS and solve_Sandholm1 (src/SampledGames/Polymatrix/solve.jl),
# and normalgame_equilibrium_to_profile via their return value.
@testitem "Solving polymatrix game" setup = [Utilities, SCIPOptimizer] begin
    game = get_example_two_player_game_usingIPG()
    x1 = only(IPG.get_player_variables(game.players[1]))
    x2 = only(IPG.get_player_variables(game.players[2]))
    timer = SGM.SGMTimer(Inf64)

    # Player 1 chooses from {10, 5}, player 2 from {1, 5}.
    #
    # Player 1's payoffs are -90 and -50 for x1 = 10, against -20 and 0 for
    # x1 = 5, so x1 = 5 dominates. Given x1 = 5, player 2 gets 4 from x2 = 1 and
    # 0 from x2 = 5. The sampled game therefore has the pure equilibrium (5, 1).
    strategies = [
        [IPG.PureStrategy(1, Dict(x1 => 10.0)), IPG.PureStrategy(1, Dict(x1 => 5.0))],
        [IPG.PureStrategy(2, Dict(x2 => 1.0)), IPG.PureStrategy(2, Dict(x2 => 5.0))],
    ]

    sampled_game = SGM.PolymatrixSampledGame(game, strategies, timer)

    equilibrium_PNS = SGM.solve_PNS(sampled_game, timer, scip_optimizer)
    equilibrium_Sandholm = SGM.solve_Sandholm1(sampled_game, timer, scip_optimizer)

    for equilibrium in (equilibrium_PNS, equilibrium_Sandholm)
        @test equilibrium isa IPG.Profile
        @test length(equilibrium) == 2
        @test IPG.value(IPG.strategy(equilibrium, 1), x1) ≈ 5.0
        @test IPG.value(IPG.strategy(equilibrium, 2), x2) ≈ 1.0
    end

    # solve_Sandholm1 shifts the polymatrix to remove negative entries, but on a
    # deep copy, so the caller's sampled game is left intact.
    @test sampled_game.polymatrix == SGM.get_polymatrix(game, strategies, timer)

    # solve dispatches to PNS by default.
    @test IPG.value(IPG.strategy(SGM.solve(sampled_game, timer, scip_optimizer), 1), x1) ≈ 5.0
end
