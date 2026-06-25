using TestItems

@testsnippet Utilities begin
    using SGM
    using JuMP

    function get_example_two_player_game(; optimizer = SGM.Optimizer(nothing, nothing))
        player_1 = Model()
        @variable(player_1, x1, start = 10.0)
        @constraint(player_1, x1 >= 0)

        player_2 = Model()
        @variable(player_2, x2, start = 10.0)
        @constraint(player_2, x2 >= 0)

        x2_parameter = @variable(player_1, set = Parameter(10.0), base_name = "x2")
        x1_parameter = @variable(player_2, set = Parameter(10.0), base_name = "x1")

        function player_payoff(x_self, x_other)
            return -x_self * x_self + x_self * x_other
        end

        @objective(player_1, Max, player_payoff(x1, x2_parameter))
        @objective(player_2, Max, player_payoff(x2, x1_parameter))

        players = [player_1, player_2]
        var_to_param_maps = [
            Dict(x2 => x2_parameter),
            Dict(x1 => x1_parameter),
        ]

        return SGM.IPGModel(players, var_to_param_maps, optimizer)
    end
end

@testitem "Package loads" begin
    using SGM

    @test SGM isa Module
end

@testitem "Example 5.3 two-player game" setup = [Utilities] begin
    game = get_example_two_player_game()

    @test game isa SGM.IPGModel
    @test length(game.players) == 2
    @test length(game.var_to_param_maps) == 2

    # TODO: this could be replaced with a proper method to get a player's variables
    player_1_variables = filter(variable -> !JuMP.is_parameter(variable), all_variables(game.players[1]))
    player_2_variables = filter(variable -> !JuMP.is_parameter(variable), all_variables(game.players[2]))

    @test length(player_1_variables) == 1
    @test length(player_2_variables) == 1
    @test JuMP.start_value(only(player_1_variables)) == 10.0
    @test JuMP.start_value(only(player_2_variables)) == 10.0

    @test haskey(game.var_to_param_maps[1], only(player_2_variables))
    @test haskey(game.var_to_param_maps[2], only(player_1_variables))
    @test JuMP.is_parameter(game.var_to_param_maps[1][only(player_2_variables)])
    @test JuMP.is_parameter(game.var_to_param_maps[2][only(player_1_variables)])

    optimize!(game.optimizer, game; enumeration=false)

    eq = get_equilibrium(game.optimizer)

    @test eq isa SGM.Profile

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
