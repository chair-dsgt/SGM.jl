include("test_utils.jl")

@testitem "Variable to parameter mapping" setup = [Utilities] begin
    game = get_example_two_player_game()

    for p in 1:length(game.players)
        @test all(!JuMP.is_parameter(k) for k in keys(game.var_to_param_maps[p]))
        @test all(JuMP.is_parameter(k) for k in values(game.var_to_param_maps[p]))
    end
end
