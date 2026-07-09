function solve_normal_form(sampled_game::NormalFormSampledGame, optimizer_factory, timer::SGMTimer)::Profile
    check_time(timer)

    sol =  compute_nash_equilibria(sampled_game.nGame, 1, remaining_time(timer))
    check_time(timer)
    multiplayer_eq = sol[3]

    profile = Strategy[]

    for id in eachindex(sampled_game.strategy_sample)
        mixed_strategy = MixedStrategy(id, multiplayer_eq[id], sampled_game.strategy_sample[id])
        push!(profile, mixed_strategy)
    end
    check_time(timer)

    return profile
end

function solve(sampled_game::NormalFormSampledGame, optimizer_factory, timer::SGMTimer)::Profile
    return solve_normal_form(sampled_game, optimizer_factory, timer) 
end