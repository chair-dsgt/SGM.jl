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
    if length(game.players) == 2
        return get_polymatrix_twoplayers(game, strategies)
    else
        # TODO: get_polymatrix_bilateral
        error("Polymatrix bilateral games (more than 2 players) are not implemented yet")
    end
end

function update_polymatrix!(polymatrix::Polymatrix, p::Int, game::IPGModel, strategies::Vector{Vector{PureStrategy}})::Nothing
    other_players = deleteat!(collect(1:length(game.players)), p) # Other players' ids 

    old_num_strats_p = size(polymatrix[(p, other_players[1])], 1) # Number of player p's strategies already stored in polymatrix

    sub_strategies = copy(strategies)
    sub_strategies[p] = strategies[p][(old_num_strats_p + 1):end]
    new_strats_polymatrix = get_polymatrix(game, sub_strategies)

    for k in other_players
        polymatrix[(p,k)] = [polymatrix[(p,k)]; new_strats_polymatrix[(p,k)]]
        polymatrix[(k,p)] = [polymatrix[(k,p)] new_strats_polymatrix[(k,p)]] 
    end
    polymatrix[(p,p)] = Matrix(Diagonal([diag(polymatrix[(p,p)]); diag(new_strats_polymatrix[(p,p)])]))

    return nothing
end

function negative_polymatrix_preprocessing!(polymatrix::Polymatrix)::Polymatrix
    offset = 0.0
    for k in keys(polymatrix)
        offset = min(offset, minimum(polymatrix[k]))
    end
    for k in keys(polymatrix)
        polymatrix[k] = polymatrix[k] .- offset
    end
    return polymatrix
end