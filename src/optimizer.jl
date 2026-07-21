mutable struct Optimizer <: IPG.IPGOptimizer 
    best_response_optimizer
    equilibrium_computation_optimizer # Unnecessary? => our equilibrium computation solvers don't use it (they all use their own optimizer)
    termination_status::IPG.TerminationStatusCode
    equilibrium::Union{Nothing,IPG.Profile}
    supports_enumeration::Bool
    candidate_equilibria::Vector{IPG.Profile}
    function Optimizer(best_response_optimizer, equilibrium_computation_optimizer)
        return new(
            best_response_optimizer,
            equilibrium_computation_optimizer,
            IPG.SOLVE_NOT_CALLED,
            nothing,
            false,
            IPG.Profile[])
    end
end

"""
    get_equilibrium(optimizer::SGM.Optimizer)::IPG.Profile
    get_equilibrium(optimizer::SGM.Optimizer, i::Int)::IPG.Profile

Return an equilibrium stored in `optimizer`.

The function `get_equilibrium(optimizer, i)` returns the `i`-th equilibrium stored in the optimizer. An error is returned if `i` is out of bounds.

This function can only be called after `search!` has been called.
"""
function get_equilibrium(optimizer::Optimizer)::IPG.Profile
    if optimizer.equilibrium === nothing
        error("No equilibrium is available")
    end
    
    return optimizer.equilibrium
end
function get_equilibrium(optimizer::Optimizer, i::Int)::IPG.Profile
    if i == 1
        if optimizer.equilibrium === nothing
            error("No equilibrium is available")
        end
    
    return optimizer.equilibrium
    end

    error("SGM.Optimizer does not support equilibria enumeration, therefore i is out of bounds")
end

function get_equilibria(optimizer::Optimizer)::Vector{IPG.Profile}
    error("SGM.Optimizer does not support equilibria enumeration")
end

"""
    get_termination_status(optimizer::SGM.Optimizer)::IPG.TerminationStatusCode

Return an `IPG.TerminationStatusCode` describing why the SGM solver stopped.
"""
function get_termination_status(optimizer::Optimizer)::IPG.TerminationStatusCode
    return optimizer.termination_status
end