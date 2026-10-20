# Tests for the SGM/eSGM algorithm: SGM.EquilibriumSolver as an implementation
# of the IPG.EquilibriumSolver interface.
#
# Assertions about how a model is built - IPGModel construction, the
# @variable/@constraint/@payoff macros, the variable-to-parameter map, player
# name resolution, and the Int/String equivalence of the accessors - belong to
# IPG.jl and live in IPG.jl/test. What is asserted here is what the algorithm
# does with a model: that it terminates correctly, which candidate equilibria it
# visits, and that the profile it returns really is an equilibrium.

@testitem "Package loads" begin
    using SGM

    @test SGM isa Module
end

# Covers: sgm_search! on a continuous quadratic game, including the sequence of
# candidate equilibria it visits (SGM.EquilibriumSolver.candidate_equilibria is
# SGM-private state) and the no-profitable-deviation certificate.
@testitem "Example 5.3 two-player game" setup = [Utilities, SCIPOptimizer] begin     # From "Computing equilibria for integer programming games"
    game = get_example_two_player_game_usingIPG(equilibrium_solver = SGM.EquilibriumSolver(scip_optimizer))

    player_1_variables = IPG.get_player_variables(game.players[1])
    player_2_variables = IPG.get_player_variables(game.players[2])

    @test IPG.termination_status(game) == IPG.SOLVE_NOT_CALLED

    @test IPG.find_equilibrium!(game; dev_tol=E_SGM) === nothing

    @test IPG.termination_status(game) == IPG.EQUILIBRIUM_FOUND

    eq = IPG.equilibrium(game)

    @test eq isa IPG.Profile

    candidate_equilibria = game.equilibrium_solver.candidate_equilibria

    @test [[only(profile[1].supp).variable_values[only(player_1_variables)]] for profile in candidate_equilibria[1:5]] ≈ [
        [10.0],
        [5.0],
        [5.0],
        [1.25],
        [1.25]
    ]

    @test [[only(profile[2].supp).variable_values[only(player_2_variables)]] for profile in candidate_equilibria[1:5]] ≈ [
        [10.0],
        [10.0],
        [2.5],
        [2.5],
        [0.625]
    ]

    for i in 1:length(game.players)
        A_i = IPG.payoff(game, i, eq)

        eq_others = IPG.Strategy[strategy for strategy in eq if strategy.id != i]
        best_response_strat = IPG.best_response(game, i, eq_others, game.equilibrium_solver.best_response_optimizer)
        new_profile = IPG.Strategy[strategy.id == i ? best_response_strat : strategy for strategy in eq]

        B_i = IPG.payoff(game, i, new_profile)

        @test abs(A_i - B_i) <= E_true
    end

    @test only(eq[1].probs) ≈ 1.0
    @test only(eq[2].probs) ≈ 1.0
end

# Covers: sgm_search! recovering a genuinely mixed equilibrium over binary
# strategies. This is the only fixture whose equilibrium has support larger than
# one, so it is the load-bearing test for the sampled-game solve.
#
# The best_response calls below are here to certify the equilibrium, not to test
# best_response itself - that is covered directly in IPG.jl/test/best_response.jl.
@testitem "Rock-paper-scissors game" setup = [Utilities, SCIPOptimizer] begin
    game = get_rock_paper_scissors_game_usingIPG(equilibrium_solver = SGM.EquilibriumSolver(scip_optimizer))

    @test IPG.termination_status(game) == IPG.SOLVE_NOT_CALLED

    @test IPG.find_equilibrium!(game; dev_tol=E_SGM) === nothing

    @test IPG.termination_status(game) == IPG.EQUILIBRIUM_FOUND

    eq = IPG.equilibrium(game)

    @test eq isa IPG.Profile

    for i in 1:length(game.players)
        A_i = IPG.payoff(game, i, eq)

        eq_others = IPG.Strategy[strategy for strategy in eq if strategy.id != i]
        best_response_strat = IPG.best_response(game, i, eq_others, game.equilibrium_solver.best_response_optimizer)
        new_profile = IPG.Strategy[strategy.id == i ? best_response_strat : strategy for strategy in eq]

        B_i = IPG.payoff(game, i, new_profile)

        @test abs(A_i - B_i) <= E_true
    end

    @test eq[1].probs[1] ≈ 1/3
    @test eq[1].probs[2] ≈ 1/3
    @test eq[1].probs[3] ≈ 1/3
    @test eq[2].probs[1] ≈ 1/3
    @test eq[2].probs[2] ≈ 1/3
    @test eq[2].probs[3] ≈ 1/3
end

# Covers: sgm_search! beyond two players, on a mixed-integer game whose
# best-response problems are MIQP.
@testitem "Example three-player game" setup = [Utilities, SCIPOptimizer] begin     # From "When do Mixed-Integer Games Admit Rational Equilibria?"
    game = get_example_three_player_game_usingIPG(equilibrium_solver = SGM.EquilibriumSolver(scip_optimizer))

    @test IPG.termination_status(game) == IPG.SOLVE_NOT_CALLED

    @test IPG.find_equilibrium!(game; dev_tol=E_SGM) === nothing

    @test IPG.termination_status(game) == IPG.EQUILIBRIUM_FOUND

    eq = IPG.equilibrium(game)

    @test eq isa IPG.Profile
    @test length(eq) == 3

    for i in 1:length(game.players)
        A_i = IPG.payoff(game, i, eq)

        eq_others = IPG.Strategy[strategy for strategy in eq if strategy.id != i]
        best_response_strat = IPG.best_response(game, i, eq_others, game.equilibrium_solver.best_response_optimizer)
        new_profile = IPG.Strategy[strategy.id == i ? best_response_strat : strategy for strategy in eq]

        B_i = IPG.payoff(game, i, new_profile)

        @test abs(A_i - B_i) <= E_true
    end
end

# Covers: SGM.initialize_strategies (src/initialization.jl:48), specifically that
# a player's start values seed the first sampled strategy when present, and that
# a feasibility solve supplies one when they are not.
@testitem "Initialization" setup = [Utilities] begin
    game = get_example_two_player_game_usingIPG()
    players = game.players
    num_players = length(players)
    x1 = only(IPG.get_player_variables(game.players[1]))
    x2 = only(IPG.get_player_variables(game.players[2]))

    JuMP.set_start_value(x1, nothing)

    sampled_strategies = SGM.initialize_strategies(
        players,
        num_players,
        mock_feasibility_optimizer,
        SGM.SGMTimer(Inf64)
    )

    @test length(sampled_strategies) == num_players
    @test all(length(strategies) == 1 for strategies in sampled_strategies)
    @test only(sampled_strategies[1]).id == 1
    @test only(sampled_strategies[2]).id == 2

    x1_strategy = only(sampled_strategies[1])
    x2_strategy = only(sampled_strategies[2])

    @test Set(keys(x1_strategy.variable_values)) == Set([x1])
    @test Set(keys(x2_strategy.variable_values)) == Set([x2])
    @test only(values(x1_strategy.variable_values)) >= 0.0
    @test x2_strategy.variable_values == Dict(x2 => 10.0)

    JuMP.set_start_value(x2, nothing)

    sampled_strategies = SGM.initialize_strategies(
        players,
        num_players,
        mock_feasibility_optimizer,
        SGM.SGMTimer(Inf64)
    )

    @test length(sampled_strategies) == num_players
    @test all(length(strategies) == 1 for strategies in sampled_strategies)

    for (player_id, strategies) in enumerate(sampled_strategies)
        strategy = only(strategies)
        @test strategy.id == player_id
        xs = IPG.get_player_variables(players[player_id])
        @test length(strategy.variable_values) == length(xs)
        @test all(value == 0.0 for value in values(strategy.variable_values))
    end
end
