# TODO: refactor this into a submodule of SGM

const Polymatrix = Dict{Tuple{Int, Int}, Matrix{Float64}} 

mutable struct PolymatrixSampledGame
    strategy_sample::Vector{Vector{PureStrategy}}
    polymatrix::Polymatrix
end

function PolymatrixSampledGame(model::IPGModel, strategies::Vector{Vector{PureStrategy}})::PolymatrixSampledGame
    return PolymatrixSampledGame(strategies, get_polymatrix(model, strategies))
end

# TODO: add tests for the function below
function get_polymatrix_twoplayers(game::IPGModel, strategies::Vector{Vector{PureStrategy}})::Polymatrix
    # Initialization
    polymatrix = Polymatrix()
    polymatrix[(1,1)] = zeros(length(strategies[1]), length(strategies[1]))
    polymatrix[(2,2)] = zeros(length(strategies[2]), length(strategies[2]))
    polymatrix[(1,2)] = zeros(length(strategies[1]), length(strategies[2]))
    polymatrix[(2,1)] = zeros(length(strategies[2]), length(strategies[1]))

    for i1 in eachindex(strategies[1])
        for i2 in eachindex(strategies[2])
            profile = [strategies[1][i1], strategies[2][i2]]
            polymatrix[(1,2)][i1,i2] = compute_payoff_at_profile(game, 1, profile)
            polymatrix[(2,1)][i2,i1] = compute_payoff_at_profile(game, 2, profile)
        end
    end

    return polymatrix
end

function get_polymatrix(game::IPGModel, strategies::Vector{Vector{PureStrategy}})::Polymatrix
    if length(players) == 2
        return get_polymatrix_twoplayers(game, strategies)
    else
        # TODO: get_polymatrix_bilateral
        error("Polymatrix bilateral games are not implemented yet")
    end
end