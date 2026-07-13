mutable struct Optimizer <: IPGOptimizer 
    best_response_optimizer
    equilibrium_computation_optimizer # Unnecessary? => our equilibrium computation solvers don't use it (they all use their own optimizer)
    termination_status::TerminationStatusCode
    equilibrium::Union{Nothing,Profile}
    supports_enumeration::Bool
    function Optimizer(best_response_optimizer, equilibrium_computation_optimizer)
        return new(
            best_response_optimizer,
            equilibrium_computation_optimizer,
            SOLVE_NOT_CALLED,
            nothing,
            false)
    end
end

"""
    get_equilibrium(optimizer::SGM.Optimizer)::Profile

Return an equilibrium stored in `optimizer`.

This function can only be called after `search!` has been called.
"""
function get_equilibrium(optimizer::Optimizer)::Profile
    if optimizer.equilibrium === nothing
        error("No equilibrium is available; find_equilibrium! must be called first")
    end
    
    return optimizer.equilibrium
end

"""
    get_termination_status(optimizer::SGM.Optimizer)::IPG.TerminationStatusCode

Return an `IPG.TerminationStatusCode` describing why the SGM solver stopped.
"""
function get_termination_status(optimizer::Optimizer)::TerminationStatusCode
    return optimizer.termination_status
end