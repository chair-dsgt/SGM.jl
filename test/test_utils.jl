using SGM
using TestItems

# SCIP is used by the subroutine tests that need a best-response solve but not
# the full SGM algorithm. It needs no licence, so those tests run anywhere. The
# end-to-end solver tests still use Gurobi, as does NormalGames.jl internally.
@testsnippet SCIPOptimizer begin
    using JuMP
    using SCIP

    scip_optimizer = JuMP.optimizer_with_attributes(
        SCIP.Optimizer,
        "display/verblevel" => 0,
        "limits/gap" => 0.0,
    )
end

@testsnippet Gurobi begin
    using Gurobi

    a = 0.1
    E_true = 1e-6
    E_SGM = (1 - a) * E_true
    E_MIP = a * E_true

    gurobi_optimizer = JuMP.optimizer_with_attributes(Gurobi.Optimizer, "OutputFlag" => 0, "MIPGap" => 0.0, "MIPGapAbs" => E_MIP, "Threads" => 1, "Seed" => 1)
end

# Game fixtures for the solver tests.
#
# These are built through the IPG macros rather than by hand, so SGM is
# exercised over the same models its users construct. Assertions about the
# construction itself belong to IPG.jl and live in IPG.jl/test/model.jl; what is
# asserted here is what the SGM algorithm does with the resulting model.
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
