function normal_game(sampled_game::PolymatrixSampledGame)::NormalGame
    num_players = length(sampled_game.strategy_sample)
    num_strategies = length.(sampled_game.strategy_sample)
    return NormalGame(num_players, num_strategies, sampled_game)
end