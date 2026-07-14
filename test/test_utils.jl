using SGM
using TestItems

@testsnippet Utilities begin
    using JuMP

    function mock_feasibility_optimizer()
        optimizer = JuMP.MOI.Utilities.MockOptimizer(
            JuMP.MOI.Utilities.UniversalFallback(JuMP.MOI.Utilities.Model{Float64}()),
        )
        JuMP.MOI.Utilities.set_mock_optimize!(optimizer, mock -> begin
            variables = JuMP.MOI.get(mock, JuMP.MOI.ListOfVariableIndices())
            return JuMP.MOI.Utilities.mock_optimize!(mock, zeros(length(variables)))
        end)
        return optimizer
    end

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

    function get_rock_paper_scissors_game(; optimizer = SGM.Optimizer(nothing,nothing))
        player_1 = Model()
        @variable(player_1, r1, Bin, start = 1.0)
        @variable(player_1, p1, Bin, start = 0.0)
        @variable(player_1, s1, Bin, start = 0.0)
        @constraint(player_1, r1 + p1 + s1 == 1)

        player_2 = Model()
        @variable(player_2, r2, Bin, start = 1.0)
        @variable(player_2, p2, Bin, start = 0.0)
        @variable(player_2, s2, Bin, start = 0.0)
        @constraint(player_2, r2 + p2 + s2 == 1)

        r2_parameter = @variable(player_1, set = Parameter(1.0), base_name = "r2")
        p2_parameter = @variable(player_1, set = Parameter(0.0), base_name = "p2")
        s2_parameter = @variable(player_1, set = Parameter(0.0), base_name = "s2")

        r1_parameter = @variable(player_2, set = Parameter(1.0), base_name = "r1")
        p1_parameter = @variable(player_2, set = Parameter(0.0), base_name = "p1")
        s1_parameter = @variable(player_2, set = Parameter(0.0), base_name = "s1")

        @objective(player_1, Max, -r1 * p2_parameter + r1 * s2_parameter + p1 * r2_parameter - p1 * s2_parameter - s1 * r2_parameter + s1 * p2_parameter)
        @objective(player_2, Max, r1_parameter * p2 - r1_parameter * s2 - p1_parameter * r2 + p1_parameter * s2 + s1_parameter * r2 - s1_parameter * p2)

        players = [player_1, player_2]
        var_to_param_maps = [
            Dict(r2 => r2_parameter,
                 p2 => p2_parameter,
                 s2 => s2_parameter),
            Dict(r1 => r1_parameter,
                 p1 => p1_parameter,
                 s1 => s1_parameter),
        ]

        return SGM.IPGModel(players, var_to_param_maps, optimizer)
    end
end
