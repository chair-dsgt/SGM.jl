include("test_utils.jl")

@testitem "Package loads" begin
    using SGM

    @test SGM isa Module
end

@testitem "Example 5.3 two-player game" setup = [Utilities] begin
    game = get_example_two_player_game(optimizer = SGM.Optimizer(mock_feasibility_optimizer, mock_feasibility_optimizer))

    @test game isa SGM.IPGModel
    @test length(game.players) == 2
    @test length(game.var_to_param_maps) == 2

    player_1_variables = SGM.get_player_variables(game.players[1])
    player_2_variables = SGM.get_player_variables(game.players[2])

    @test length(player_1_variables) == 1
    @test length(player_2_variables) == 1
    @test JuMP.start_value(only(player_1_variables)) == 10.0
    @test JuMP.start_value(only(player_2_variables)) == 10.0

    @test haskey(game.var_to_param_maps[1], only(player_2_variables))
    @test haskey(game.var_to_param_maps[2], only(player_1_variables))
    @test JuMP.is_parameter(game.var_to_param_maps[1][only(player_2_variables)])
    @test JuMP.is_parameter(game.var_to_param_maps[2][only(player_1_variables)])

    @test SGM.get_termination_status(game.optimizer) == SGM.SOLVE_NOT_CALLED

    @test SGM.optimize!(game.optimizer, game; enumeration=false) === nothing

    @test SGM.get_termination_status(game.optimizer) == SGM.EQUILIBRIUM_FOUND

    eq = SGM.get_equilibrium(game.optimizer)

    @test eq isa SGM.Profile

    # TODO: test value of the equilibrium found

    # TODO: adapt the following tests to the new structure
    # @test [σ[players[1]].supp for σ in Σ] ≈ [
    #     [[10.0]],
    #     [[10.0]],
    #     [[2.5]],
    #     [[2.5]],
    #     [[0.625]]
    # ]
    # @test [σ[players[2]].supp for σ in Σ] ≈ [
    #     [[10.0]],
    #     [[5.0]],
    #     [[5.0]],
    #     [[1.25]],
    #     [[1.25]]
    # ]
end

@testitem "Initialization" setup = [Utilities] begin
    game = get_example_two_player_game()
    players = game.players
    num_players = length(players)
    x1 = only(SGM.get_player_variables(game.players[1]))
    x2 = only(SGM.get_player_variables(game.players[2]))

    JuMP.set_start_value(x1, nothing)

    sampled_strategies = SGM.initialize_strategies(
        players,
        num_players,
        mock_feasibility_optimizer,
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
    )

    @test length(sampled_strategies) == num_players
    @test all(length(strategies) == 1 for strategies in sampled_strategies)

    for (player_id, strategies) in enumerate(sampled_strategies)
        strategy = only(strategies)
        @test strategy.id == player_id
        xs = SGM.get_player_variables(players[player_id])
        @test length(strategy.variable_values) == length(xs)
        @test all(value == 0.0 for value in values(strategy.variable_values))
    end
end
