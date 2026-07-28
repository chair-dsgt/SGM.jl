struct NGame
    n::Int # Number of players
    strat::Vector{Int} # Number of strategies per player
    utilities::Array{Float64}  # n+1 dimensional: (s₁, ..., sₙ, n)
end

mutable struct NormalFormSampledGame
    strategy_sample::Vector{Vector{IPG.PureStrategy}}
    nGame::NGame
end

function NormalFormSampledGame(model::IPG.IPGModel, strategies::Vector{Vector{IPG.PureStrategy}}, timer::SGMTimer)::NormalFormSampledGame
    return NormalFormSampledGame(strategies, get_normal_form(model, strategies, timer))
end

function get_normal_form(model::IPG.IPGModel, strategies::Vector{Vector{IPG.PureStrategy}}, timer)::NGame
    num_players = length(model.players)
    if num_players < 2
        model.equilibrium_solver.termination_status = IPG.INVALID_MODEL
        error("An IPG must have atleast 2 players")
    end

    num_strategies = length.(strategies)

    utilities = zeros(num_strategies..., num_players)
    strategy_ranges = [1:num_strategies[p] for p in 1:num_players]
    for profile_ids in Iterators.product(strategy_ranges...) 
        check_time(timer)
        profile = IPG.PureStrategy[]
        for player_id in 1:num_players
            strategy_id = profile_ids[player_id]
            push!(profile, strategies[player_id][strategy_id])
        end
        check_time(timer)

        for player_id in 1:num_players
            utilities[profile_ids..., player_id] = IPG.comparable_payoff_value(model, player_id, profile)
            check_time(timer)
        end
    end

    return NGame(num_players, num_strategies, utilities)
end

# Expects that only one strategy was added for player p, and that it was added at the end of the strategy vector.
function update_sampled_game!(normal_form_sampled_game::NormalFormSampledGame, p::Int, model::IPG.IPGModel, timer::SGMTimer)::Nothing
    new_strategies = normal_form_sampled_game.strategy_sample
    new_num_strategies = length.(new_strategies)
    new_strategy_id = new_num_strategies[p] # The new strategy is always added at the end of the strategy vector
    old_ngame = normal_form_sampled_game.nGame
    num_players = old_ngame.n

    new_utilities = zeros(new_num_strategies..., num_players)

    old_strategy_ranges = [1:s for s in old_ngame.strat]
    new_utilities[old_strategy_ranges..., :] .= old_ngame.utilities # Copy old utilities into new utility array

    new_strategy_ranges = [player_id == p ? (new_strategy_id:new_strategy_id) : 1:new_num_strategies[player_id] for player_id in 1:num_players]

    for profile_ids in Iterators.product(new_strategy_ranges...)
        check_time(timer)
        profile = IPG.PureStrategy[]
        for player_id in 1:num_players
            strategy_id = profile_ids[player_id]
            push!(profile, new_strategies[player_id][strategy_id])
        end
        check_time(timer)

        for player_id in 1:num_players
            new_utilities[profile_ids..., player_id] = IPG.comparable_payoff_value(model, player_id, profile)
            check_time(timer)
        end
    end

    normal_form_sampled_game.nGame = NGame(num_players, new_num_strategies, new_utilities)

    return nothing
end



