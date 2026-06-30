# Temporary code for basic IPG structures before IPG.jl is implemented

abstract type IPGOptimizer 
end 

mutable struct IPGModel
    players::Vector{JuMP.Model} 
    # Each player has a dictionary that maps another player's variable to the parameter representing it in this player's model.
    var_to_param_maps::Vector{Dict{JuMP.VariableRef, JuMP.VariableRef}} 

    optimizer::IPGOptimizer
end

struct PureStrategy
    id::Int # Player id
    variable_values::Dict{JuMP.VariableRef, Float64}
end

struct MixedStrategy
    id::Int # Player id
    probs::Vector{Float64} # Probability vector
    supp::Vector{PureStrategy} # Vector of pure strategies (support)
    function MixedStrategy(id::Int, probs::Vector{Float64}, supp::Vector{PureStrategy})
        if length(probs) != size(supp, 1)
            error("There must be as many probabilities as strategies in the support.")
        end
        if ~(sum(probs) ≈ 1)
            error("Probabilities must sum to 1.")
        end
        if any(probs .< 0)
            error("Probabilities must be non-negative.")
        end

        # remove strategies with zero probability
        return new(id, probs[probs .> 0], supp[probs .> 0])
    end
end

const Strategy = Union{PureStrategy, MixedStrategy}

const Profile = Vector{T} where T <: Strategy

@enum TerminationStatusCode begin
    SOLVE_NOT_CALLED
    EQUILIBRIUM_FOUND
    ENUMERATION_COMPLETE
    NO_EQUILIBRIUM
    INFEASIBLE
    ITERATION_LIMIT
    TIME_LIMIT
    NODE_LIMIT
    MEMORY_LIMIT
    OTHER_LIMIT
    SLOW_PROGRESS
    NUMERICAL_ERROR
    INVALID_MODEL
    INVALID_OPTION
    INTERRUPTED
    OTHER_ERROR
end