struct NGame
    n::Int # Number of players
    strat::Vector{Int} # Number of strategies per player
    utilities::Array{Float64}  # n+1 dimensional: (s₁, ..., sₙ, n)
end

mutable struct NormalFormSampledGame
    strategy_sample::Vector{Vector{PureStrategy}}
    nGame::NGame
end

function NormalFormSampledGame(model::IPGModel, strategies::Vector{Vector{PureStrategy}}, timer::SGMTimer)::NormalFormSampledGame
    return NormalFormSampledGame(strategies, get_normal_form(model, strategies, timer))
end

function get_normal_form(model::IPGModel, strategies::Vector{Vector{PureStrategy}}, timer)::NGame
    num_players = length(model.players)
    if num_players < 2
        model.optimizer.termination_status = INVALID_MODEL
        error("An IPG must have atleast 2 players")
    end

    num_strategies = length.(strategies)

    utilities = zeros(num_strategies..., num_players)
    strategy_ranges = [1:num_strategies[p] for p in 1:num_players]
    for profile_ids in Iterators.product(strategy_ranges...) 
        check_time(timer)
        profile = PureStrategy[]
        for player_id in 1:num_players
            strategy_id = profile_ids[player_id]
            push!(profile, strategies[player_id][strategy_id])
        end
        check_time(timer)

        for player_id in 1:num_players
            utilities[profile_ids..., player_id] = compute_payoff_at_profile(model, player_id, profile)
            check_time(timer)
        end
    end

    return NGame(num_players, num_strategies, utilities)
end

function update_sampled_game!(normal_form_sampled_game::NormalFormSampledGame, p::Int, model::IPGModel, timer::SGMTimer)::Nothing
    normal_form_sampled_game.nGame = get_normal_form(model, normal_form_sampled_game.strategy_sample, timer)

    return nothing
end



