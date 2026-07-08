function solve_normal_form(sampled_game::NormalFormSampledGame, optimizer_factory)::Profile
    sol =  compute_nash_equilibria(sampled_game.nGame)
    multiplayer_eq = sol[3]

    profile = Strategy[]

    for id in eachindex(sampled_game.strategy_sample)
        mixed_strategy = MixedStrategy(id, multiplayer_eq[id], sampled_game.strategy_sample[id])
        push!(profile, mixed_strategy)
    end

    return profile
end

function solve(sampled_game::NormalFormSampledGame, optimizer_factory)::Profile
    return solve_normal_form(sampled_game, optimizer_factory) 
end