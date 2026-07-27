mutable struct Optimizer <: IPG.IPGOptimizer 
    best_response_optimizer
    equilibrium_computation_optimizer # Unnecessary? => our equilibrium computation solvers don't use it (they all use their own optimizer)
    termination_status::IPG.TerminationStatusCode
    equilibrium::Union{Nothing,IPG.Profile}
    equilibria::Vector{IPG.Profile}
    candidate_equilibria::Vector{IPG.Profile}
    function Optimizer(best_response_optimizer, equilibrium_computation_optimizer)
        return new(
            best_response_optimizer,
            equilibrium_computation_optimizer,
            IPG.SOLVE_NOT_CALLED,
            nothing,
            IPG.Profile[],
            IPG.Profile[])
    end
end

"""
    get_equilibrium(optimizer::IPGOptimizer)::Profile
    get_equilibrium(optimizer::IPGOptimizer, i::Int)::Profile

Return an equilibrium stored in `optimizer`.

If multiple equilibria are stored, `get_equilibrium(optimizer)` returns the first one. The function `get_equilibrium(optimizer, i)` 
returns the `i`-th equilibrium stored in the optimizer. An error is returned if `i` is out of bounds.

This function can only be called after `find_equilibrium!` or `find_all_equilibria!` has been called.
"""
function get_equilibrium(optimizer::Optimizer)::IPG.Profile
    if optimizer.equilibrium === nothing && isempty(optimizer.equilibria)
        error("No equilibrium is available")
    end

    if optimizer.equilibrium === nothing
        return optimizer.equilibria[1]
    end
    
    return optimizer.equilibrium
end
function get_equilibrium(optimizer::Optimizer, i::Int)::IPG.Profile
    if isempty(optimizer.equilibria)
        if optimizer.equilibrium === nothing
            error("No equilibria are available.")
        end
        if i == 1
            return optimizer.equilibrium
        else
            throw(ArgumentError("i is out of bounds"))
        end
    end

    if i < 1 || i > length(optimizer.equilibria)
        throw(ArgumentError("i is out of bounds"))
    end

    return optimizer.equilibria[i]
end

"""
    get_equilibria(optimizer::IPGOptimizer)::Vector{Profile}

Return the list of equilibria stored in `optimizer`.

Can only be called after `find_all_equilibria!` has been called.
"""
function get_equilibria(optimizer::Optimizer)::Vector{IPG.Profile}
    if isempty(optimizer.equilibria)
        error("No equilibria are available.")
    end

    return optimizer.equilibria
end

"""
    get_termination_status(optimizer::SGM.Optimizer)::IPG.TerminationStatusCode

Return an `IPG.TerminationStatusCode` describing why the SGM solver stopped.
"""
function get_termination_status(optimizer::Optimizer)::IPG.TerminationStatusCode
    return optimizer.termination_status
end

"""
    supports_enumeration(optimizer::Optimizer)::Bool

Return `true` if `optimizer` supports enumeration and return `false` otherwise.
"""
function supports_enumeration(optimizer::Optimizer)::Bool
    return true
end