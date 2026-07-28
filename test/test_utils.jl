using SGM
using TestItems

@testsnippet Utilities begin
    using JuMP
    using IPG

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

    function get_example_two_player_game(; equilibrium_solver = SGM.EquilibriumSolver(nothing))
        player_1 = Model()
        JuMP.@variable(player_1, x1, start = 10.0)
        JuMP.@constraint(player_1, x1 >= 0)

        player_2 = Model()
        JuMP.@variable(player_2, x2, start = 10.0)
        JuMP.@constraint(player_2, x2 >= 0)

        x2_parameter = JuMP.@variable(player_1, set = Parameter(10.0), base_name = "x2")
        x1_parameter = JuMP.@variable(player_2, set = Parameter(10.0), base_name = "x1")

        function player_payoff(x_self, x_other)
            return -x_self * x_self + x_self * x_other
        end

        @objective(player_1, Max, player_payoff(x1, x2_parameter))
        @objective(player_2, Max, player_payoff(x2, x1_parameter))

        players = [player_1, player_2]
        name_to_id_map = Dict{String, Int}()
        var_to_param_maps = [
            Dict(x2 => x2_parameter),
            Dict(x1 => x1_parameter),
        ]

        return IPG.IPGModel(players, name_to_id_map, var_to_param_maps, equilibrium_solver)
    end

    function get_example_two_player_game_usingIPG(; equilibrium_solver = SGM.EquilibriumSolver(nothing))
        model = IPG.IPGModel(2, equilibrium_solver)

        IPG.@variable(model, 1, x1, start = 10.0)
        IPG.@constraint(model, 1, x1 >= 0)

        IPG.@variable(model, 2, x2, start = 10.0)
        IPG.@constraint(model, 2, x2 >= 0)

        function player_payoff(x_self, x_other)
            return -x_self * x_self + x_self * x_other
        end

        IPG.@payoff(model, 1, Max, player_payoff(x1, x2))
        IPG.@payoff(model, 2, Max, player_payoff(x2, x1))

        return model
    end

    function get_example_two_player_game_with_names(; equilibrium_solver = SGM.EquilibriumSolver(nothing))
        model = IPG.IPGModel(["Player1", "Player2"], equilibrium_solver)

        IPG.@variable(model, "Player1", x1, start = 10.0)
        IPG.@constraint(model, "Player1", x1 >= 0)

        IPG.@variable(model, "Player2", x2, start = 10.0)
        IPG.@constraint(model, "Player2", x2 >= 0)

        function player_payoff(x_self, x_other)
            return -x_self * x_self + x_self * x_other
        end

        IPG.@payoff(model, "Player1", Max, player_payoff(x1, x2))
        IPG.@payoff(model, "Player2", Max, player_payoff(x2, x1))

        return model
    end

    function get_rock_paper_scissors_game(; equilibrium_solver = SGM.EquilibriumSolver(nothing))
        player_1 = Model()
        JuMP.@variable(player_1, r1, Bin, start = 1.0)
        JuMP.@variable(player_1, p1, Bin, start = 0.0)
        JuMP.@variable(player_1, s1, Bin, start = 0.0)
        JuMP.@constraint(player_1, r1 + p1 + s1 == 1)

        player_2 = Model()
        JuMP.@variable(player_2, r2, Bin, start = 1.0)
        JuMP.@variable(player_2, p2, Bin, start = 0.0)
        JuMP.@variable(player_2, s2, Bin, start = 0.0)
        JuMP.@constraint(player_2, r2 + p2 + s2 == 1)

        r2_parameter = JuMP.@variable(player_1, set = Parameter(1.0), base_name = "r2")
        p2_parameter = JuMP.@variable(player_1, set = Parameter(0.0), base_name = "p2")
        s2_parameter = JuMP.@variable(player_1, set = Parameter(0.0), base_name = "s2")

        r1_parameter = JuMP.@variable(player_2, set = Parameter(1.0), base_name = "r1")
        p1_parameter = JuMP.@variable(player_2, set = Parameter(0.0), base_name = "p1")
        s1_parameter = JuMP.@variable(player_2, set = Parameter(0.0), base_name = "s1")

        @objective(player_1, Max, -r1 * p2_parameter + r1 * s2_parameter + p1 * r2_parameter - p1 * s2_parameter - s1 * r2_parameter + s1 * p2_parameter)
        @objective(player_2, Max, r1_parameter * p2 - r1_parameter * s2 - p1_parameter * r2 + p1_parameter * s2 + s1_parameter * r2 - s1_parameter * p2)

        players = [player_1, player_2]
        name_to_id_map = Dict{String, Int}()
        var_to_param_maps = [
            Dict(r2 => r2_parameter,
                 p2 => p2_parameter,
                 s2 => s2_parameter),
            Dict(r1 => r1_parameter,
                 p1 => p1_parameter,
                 s1 => s1_parameter),
        ]

        return IPG.IPGModel(players, name_to_id_map, var_to_param_maps, equilibrium_solver)
    end

    function get_rock_paper_scissors_game_usingIPG(; equilibrium_solver = SGM.EquilibriumSolver(nothing))
        model = IPG.IPGModel(2)
        IPG.set_solver!(model, equilibrium_solver)

        IPG.@variable(model, 1, r1, Bin, start = 1.0)
        IPG.@variable(model, 1, p1, Bin, start = 0.0)
        IPG.@variable(model, 1, s1, Bin, start = 0.0)
        IPG.@constraint(model, 1, r1 + p1 + s1 == 1)

        IPG.@variable(model, 2, r2, Bin, start = 1.0)
        IPG.@variable(model, 2, p2, Bin, start = 0.0)
        IPG.@variable(model, 2, s2, Bin, start = 0.0)
        IPG.@constraint(model, 2, r2 + p2 + s2 == 1)

        IPG.@payoff(model, 1, Max, -r1 * p2 + r1 * s2 + p1 * r2 - p1 * s2 - s1 * r2 + s1 * p2)
        IPG.@payoff(model, 2, Max, r1 * p2 - r1 * s2 - p1 * r2 + p1 * s2 + s1 * r2 - s1 * p2)

        return model
    end

    function get_example_three_player_game(; equilibrium_solver = SGM.EquilibriumSolver(nothing))
        player_1 = Model()
        JuMP.@variable(player_1, y1)
        JuMP.@variable(player_1, z1, Bin)
        JuMP.@constraint(player_1, -5 * z1 <= y1)
        JuMP.@constraint(player_1, y1 <= 5 * z1)

        player_2 = Model()
        JuMP.@variable(player_2, y2)
        JuMP.@variable(player_2, z2, Bin)
        JuMP.@constraint(player_2, -5 * z2 <= y2)
        JuMP.@constraint(player_2, y2 <= 5 * z2)

        player_3 = Model()
        JuMP.@variable(player_3, -5 <= y3 <= 4)
        JuMP.@variable(player_3, z3, Bin)

        y3_param1 = JuMP.@variable(player_1, set = Parameter(0.0), base_name = "y3")
        z3_param1 = JuMP.@variable(player_1, set = Parameter(0.0), base_name = "z3")

        y3_param2 = JuMP.@variable(player_2, set = Parameter(0.0), base_name = "y3")
        z3_param2 = JuMP.@variable(player_2, set = Parameter(0.0), base_name = "z3")

        z1_param3 = JuMP.@variable(player_3, set = Parameter(0.0), base_name = "z1")
        z2_param3 = JuMP.@variable(player_3, set = Parameter(0.0), base_name = "z2")

        @objective(player_1, Min, y1^2 - y3_param1 * y1 + y3_param1 * z1 - (8 * z3_param1 - 1) * z1)
        @objective(player_2, Min, y2^2 - y3_param2 * y2 + y3_param2 * z2 + (30 * z3_param2 + 1) * z2)
        @objective(player_3, Min, (z1_param3 - z2_param3 - 1/2) * z3)

        players = [player_1, player_2, player_3]
        name_to_id_map = Dict{String, Int}()
        var_to_param_maps = [
            Dict(y3 => y3_param1,
                 z3 => z3_param1),
            Dict(y3 => y3_param2,
                 z3 => z3_param2),
            Dict(z1 => z1_param3,
                 z2 => z2_param3),
        ]

        return IPG.IPGModel(players, name_to_id_map, var_to_param_maps, equilibrium_solver)
    end

    function get_example_three_player_game_usingIPG(; equilibrium_solver = SGM.EquilibriumSolver(nothing))
        model = IPG.IPGModel(3, equilibrium_solver)
        
        IPG.@variable(model, 1, y1)
        IPG.@variable(model, 1, z1, Bin)
        IPG.@constraint(model, 1, -5 * z1 <= y1)
        IPG.@constraint(model, 1, y1 <= 5 * z1)
    
        IPG.@variable(model, 2, y2)
        IPG.@variable(model, 2, z2, Bin)
        IPG.@constraint(model, 2, -5 * z2 <= y2)
        IPG.@constraint(model, 2, y2 <= 5 * z2)
    
        IPG.@variable(model, 3, -5 <= y3 <= 4)
        IPG.@variable(model, 3, z3, Bin)
    
        IPG.@payoff(model, 1, Min, y1^2 - y3 * y1 + y3 * z1 - (8 * z3 - 1) * z1)
        IPG.@payoff(model, 2, Min, y2^2 - y3 * y2 + y3 * z2 + (30 * z3 + 1) * z2)
        IPG.@payoff(model, 3, Min, (z1 - z2 - 1/2) * z3)
    
        return model
    end
end