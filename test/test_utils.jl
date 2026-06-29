using SGM
using TestItems

@testsnippet Utilities begin
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
