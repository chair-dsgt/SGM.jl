function get_player_order_fixed_ascending(num_players::Int, ::Vector{Tuple{Int,Float64}})::Vector{Int}
    return collect(1:num_players)
end

function get_player_order_fixed_descending(num_players::Int, ::Vector{Tuple{Int,Float64}})::Vector{Int}
    return reverse(collect(1:num_players))
end

function get_player_order_random(num_players::Int, ::Vector{Tuple{Int,Float64}})::Vector{Int}
    return shuffle(collect(1:num_players))
end

function get_player_order_by_last_deviation(num_players::Int, payoff_improvements::Vector{Tuple{Int,Float64}})::Vector{Int}
    if isempty(payoff_improvements)
        return collect(1:num_players)
    end

    iterations_since_last_deviation = Dict(p => length(payoff_improvements) for p in 1:num_players)
    
    for i in 0:length(payoff_improvements)-1
        p, _ = payoff_improvements[end-i]

        if iterations_since_last_deviation[p] > i
            iterations_since_last_deviation[p] = i
        end
    end

    # sort by the number of iterations since the last deviation (decreasing)
    iterations_since_last_deviation = sort(collect(iterations_since_last_deviation), by = x -> -x[2])

    return [i for (i, _) in iterations_since_last_deviation]
end


"""
SGM subroutine that defines the order followed by `find_deviation`.

The functions take as arguments the number of players and past payoff improvements.

# Options
 - `get_player_order_by_last_deviation` (default)
 - `get_player_order_fixed_ascending`
 - `get_player_order_fixed_descending`
 - `get_player_order_random`
"""
get_player_order = get_player_order_by_last_deviation  # default value