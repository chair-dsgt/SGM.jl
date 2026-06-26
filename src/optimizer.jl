mutable struct Optimizer <: IPGOptimizer 
    best_response_optimizer
    equilibrium_computation_optimizer
    termination_status::TerminationStatusCode
    equilibrium::Union{Nothing,Profile}
    function Optimizer(best_response_optimizer, equilibrium_computation_optimizer)
        return new(
            best_response_optimizer,
            equilibrium_computation_optimizer,
            SOLVE_NOT_CALLED,
            nothing)
    end
end

function supports_enumeration(::Optimizer)::Bool return false end

"""
    get_equilibrium(optimizer::SGM.Optimizer)::Profile

Return an equilibrium stored in `optimizer`.

This function can only be called after `optimize!` has been called.
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