function solve_normal_form(sampled_game::NormalFormSampledGame, timer::SGMTimer, optimizer_factory)::IPG.Profile
    check_time(timer)

    sol = compute_nash_equilibria(sampled_game.nGame, optimizer_factory, remaining_time(timer))
    check_time(timer)
    multiplayer_eq = sol[3]

    profile = IPG.Strategy[]

    for id in eachindex(sampled_game.strategy_sample)
        mixed_strategy = IPG.MixedStrategy(id, multiplayer_eq[id], sampled_game.strategy_sample[id])
        push!(profile, mixed_strategy)
    end
    check_time(timer)

    return profile
end

function solve(sampled_game::NormalFormSampledGame, timer::SGMTimer, optimizer_factory)::IPG.Profile
    return solve_normal_form(sampled_game, timer, optimizer_factory) 
end

function solve_all(sampled_game::NormalFormSampledGame, timer::SGMTimer)::IPG.Profile
    error("Equilibria enumeration is not yet implemented for normal-form sampled games.")
end