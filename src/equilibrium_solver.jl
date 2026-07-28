mutable struct EquilibriumSolver <: IPG.EquilibriumSolver
    best_response_optimizer
    termination_status::IPG.TerminationStatusCode
    equilibrium::Union{Nothing,IPG.Profile}
    equilibria::Vector{IPG.Profile}
    candidate_equilibria::Vector{IPG.Profile}
    function EquilibriumSolver(best_response_optimizer)
        return new(
            best_response_optimizer,
            IPG.SOLVE_NOT_CALLED,
            nothing,
            IPG.Profile[],
            IPG.Profile[])
    end
end

"""
    get_equilibrium(equilibrium_solver::EquilibriumSolver)::Profile
    get_equilibrium(equilibrium_solver::EquilibriumSolver, i::Int)::Profile

Return an equilibrium stored in `equilibrium_solver`.

If multiple equilibria are stored, `get_equilibrium(equilibrium_solver)` returns the first one. The function `get_equilibrium(equilibrium_solver, i)` 
returns the `i`-th equilibrium stored in the equilibrium solver. An error is returned if `i` is out of bounds.

This function can only be called after `find_equilibrium!` or `find_all_equilibria!` has been called.
"""
function get_equilibrium(equilibrium_solver::EquilibriumSolver)::IPG.Profile
    if equilibrium_solver.equilibrium === nothing && isempty(equilibrium_solver.equilibria)
        error("No equilibrium is available")
    end

    if equilibrium_solver.equilibrium === nothing
        return equilibrium_solver.equilibria[1]
    end
    
    return equilibrium_solver.equilibrium
end
function get_equilibrium(equilibrium_solver::EquilibriumSolver, i::Int)::IPG.Profile
    if isempty(equilibrium_solver.equilibria)
        if equilibrium_solver.equilibrium === nothing
            error("No equilibria are available.")
        end
        if i == 1
            return equilibrium_solver.equilibrium
        else
            throw(ArgumentError("i is out of bounds"))
        end
    end

    if i < 1 || i > length(equilibrium_solver.equilibria)
        throw(ArgumentError("i is out of bounds"))
    end

    return equilibrium_solver.equilibria[i]
end

"""
    get_equilibria(equilibrium_solver::EquilibriumSolver)::Vector{Profile}

Return the list of equilibria stored in `equilibrium_solver`.

Can only be called after `find_all_equilibria!` has been called.
"""
function get_equilibria(equilibrium_solver::EquilibriumSolver)::Vector{IPG.Profile}
    if isempty(equilibrium_solver.equilibria)
        error("No equilibria are available.")
    end

    return equilibrium_solver.equilibria
end

"""
    get_termination_status(equilibrium_solver::EquilibriumSolver)::IPG.TerminationStatusCode

Return an `IPG.TerminationStatusCode` describing why the SGM solver stopped.
"""
function get_termination_status(equilibrium_solver::EquilibriumSolver)::IPG.TerminationStatusCode
    return equilibrium_solver.termination_status
end

"""
    supports_enumeration(equilibrium_solver::EquilibriumSolver)::Bool

Return `true` if `equilibrium_solver` supports enumeration and return `false` otherwise.
"""
function supports_enumeration(equilibrium_solver::EquilibriumSolver)::Bool
    return true
end