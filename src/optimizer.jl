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

function supports_enumeration(::Optimizer)
    return false 
end

function get_equilibrium(optimizer::Optimizer)
    if optimizer.equilibrium === nothing
        error("No equilibrium is available; find_equilibrium! must be called first")
    end
    
    return optimizer.equilibrium
end

function get_termination_status(optimizer::Optimizer)::TerminationStatusCode
    return optimizer.termination_status
end