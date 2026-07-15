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

    function get_example_three_player_game(; optimizer = SGM.Optimizer(nothing, nothing))
        player_1 = Model()
        @variable(player_1, y1)
        @variable(player_1, z1, Bin)
        @constraint(player_1, -5 * z1 <= y1)
        @constraint(player_1, y1 <= 5 * z1)

        player_2 = Model()
        @variable(player_2, y2)
        @variable(player_2, z2, Bin)
        @constraint(player_2, -5 * z2 <= y2)
        @constraint(player_2, y2 <= 5 * z2)

        player_3 = Model()
        @variable(player_3, -5 <= y3 <= 4)
        @variable(player_3, z3, Bin)

        y3_param1 = @variable(player_1, set = Parameter(0.0), base_name = "y3")
        z3_param1 = @variable(player_1, set = Parameter(0.0), base_name = "z3")

        y3_param2 = @variable(player_2, set = Parameter(0.0), base_name = "y3")
        z3_param2 = @variable(player_2, set = Parameter(0.0), base_name = "z3")

        z1_param3 = @variable(player_3, set = Parameter(0.0), base_name = "z1")
        z2_param3 = @variable(player_3, set = Parameter(0.0), base_name = "z2")

        # Example in article is a minimization problem, but current the current implementation only supports maximization
        @objective(player_1, Max, -(y1^2 - y3_param1 * y1 + y3_param1 * z1 - (8 * z3_param1 - 1) * z1))
        @objective(player_2, Max, -(y2^2 - y3_param2 * y2 + y3_param2 * z2 + (30 * z3_param2 + 1) * z2))
        @objective(player_3, Max, -((z1_param3 - z2_param3 - 1/2) * z3))

        players = [player_1, player_2, player_3]
        var_to_param_maps = [
            Dict(y3 => y3_param1,
                 z3 => z3_param1),
            Dict(y3 => y3_param2,
                 z3 => z3_param2),
            Dict(z1 => z1_param3,
                 z2 => z2_param3),
        ]

        return SGM.IPGModel(players, var_to_param_maps, optimizer)
    end
end
