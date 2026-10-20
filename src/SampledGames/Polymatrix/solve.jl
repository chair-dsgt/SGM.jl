"Convert a `PolymatrixSampledGame` into the `NormalGames.NormalGame` format."
function normal_game(sampled_game::PolymatrixSampledGame)::NormalGames.NormalGame
    num_players = length(sampled_game.strategy_sample)
    num_strategies = length.(sampled_game.strategy_sample)
    return NormalGames.NormalGame(num_players, num_strategies, sampled_game.polymatrix)
end

"Convert a Nash equilibrium from `NormalGames` to a `Profile`."
function normalgame_equilibrium_to_profile(normalgame_eq::Vector{Vector{Float64}}, strategy_sample::Vector{Vector{IPG.PureStrategy}})::IPG.Profile
    profile = IPG.Strategy[]

    for id in eachindex(strategy_sample)
        mixed_strategy = IPG.MixedStrategy(id, normalgame_eq[id], strategy_sample[id])
        push!(profile, mixed_strategy)
    end

    return profile
end

"Compute a (mixed) Nash equilibrium for the sampled game using PNS."
function solve_PNS(sampled_game::PolymatrixSampledGame, timer::SGMTimer, optimizer_factory)::IPG.Profile
    normal_sampled_game = normal_game(sampled_game)

    check_time(timer)
    _, _, equilibria = NormalGames.NashEquilibriaPNS(normal_sampled_game, optimizer_factory, false, false, true, remaining_time(timer))
    check_time(timer)

    equilibrium = equilibria[1]  # take the first Nash equilibrium

    return normalgame_equilibrium_to_profile(equilibrium, sampled_game.strategy_sample)
end

"Compute a (mixed) Nash equilibrium for the sampled game using Formulation 1 (Big-M) of Sandholm et al. (2005)."
function solve_Sandholm1(sampled_game::PolymatrixSampledGame, timer::SGMTimer, optimizer_factory)::IPG.Profile
    sampled_game_copy = deepcopy(sampled_game) # to not permanently modify the game for future use
    negative_polymatrix_preprocessing!(sampled_game_copy.polymatrix) # because this method doesn't support polymatrices with negative entries
    check_time(timer)

    normal_sampled_game = normal_game(sampled_game_copy)

    _, _, equilibrium, _, _, _, _, _ = NormalGames.NashEquilibria2(normal_sampled_game, optimizer_factory)
    check_time(timer)

    return normalgame_equilibrium_to_profile(equilibrium, sampled_game.strategy_sample)
end

function solve(sampled_game::PolymatrixSampledGame, timer::SGMTimer, optimizer_factory)::IPG.Profile
    return solve_PNS(sampled_game, timer, optimizer_factory) # Default value
end

"Compute all (mixed) Nash equilibria for the sampled game using PNS."
function solve_all(sampled_game::PolymatrixSampledGame, timer::SGMTimer, optimizer_factory)::Vector{IPG.Profile}
    normal_sampled_game = normal_game(sampled_game)

    check_time(timer)
    _, _, equilibria = NormalGames.NashEquilibriaPNS(normal_sampled_game, optimizer_factory, true, false, true, remaining_time(timer))
    check_time(timer)

    equilibrium_profiles = Vector{IPG.Profile}()
    for equilibrium in equilibria
        push!(equilibrium_profiles, normalgame_equilibrium_to_profile(equilibrium, sampled_game.strategy_sample))
    end

    return equilibrium_profiles
end